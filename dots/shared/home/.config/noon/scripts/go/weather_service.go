package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"net/http"
	"net/url"
	"os"
	"strconv"
	"strings"
	"syscall"
	"time"
)

const (
	api      = "https://wttr.in"
	ua       = "curl/7.68.0"
	lockPath = "/tmp/weather_service.lock"
)

type kv struct{ Value string `json:"value"` }

type wtCurrent struct {
	TempC         string `json:"temp_C"`
	TempF         string `json:"temp_F"`
	FeelsLikeC    string `json:"FeelsLikeC"`
	FeelsLikeF    string `json:"FeelsLikeF"`
	Humidity      string `json:"humidity"`
	WindspeedKmph string `json:"windspeedKmph"`
	Visibility    string `json:"visibility"`
	WeatherDesc   []kv   `json:"weatherDesc"`
}

type wtArea struct {
	AreaName []kv `json:"areaName"`
	Country  []kv `json:"country"`
}

type wtAstronomy struct {
	Sunrise string `json:"sunrise"`
	Sunset  string `json:"sunset"`
}

type wtHourly struct {
	Time         string `json:"time"`
	TempC        string `json:"tempC"`
	TempF        string `json:"tempF"`
	ChanceOfRain string `json:"chanceofrain"`
	WeatherDesc  []kv   `json:"weatherDesc"`
}

type wtDay struct {
	Date      string        `json:"date"`
	MaxtempC  string        `json:"maxtempC"`
	MaxtempF  string        `json:"maxtempF"`
	MintempC  string        `json:"mintempC"`
	MintempF  string        `json:"mintempF"`
	UVIndex   string        `json:"uvIndex"`
	Astronomy []wtAstronomy `json:"astronomy"`
	Hourly    []wtHourly    `json:"hourly"`
}

type wttr struct {
	CurrentCondition []wtCurrent `json:"current_condition"`
	NearestArea      []wtArea    `json:"nearest_area"`
	Weather          []wtDay     `json:"weather"`
}

func deg(v, unit string) string { return v + "°" + unit }

func timeMin(s string) time.Time {
	for _, layout := range []string{"15:04", "03:04 PM"} {
		if t, err := time.Parse(layout, strings.ToUpper(strings.TrimSpace(s))); err == nil {
			return t
		}
	}
	return time.Time{}
}

func isNight(now, sunrise, sunset string) bool {
	n := timeMin(now)
	return n.IsZero() || n.Before(timeMin(sunrise)) || n.After(timeMin(sunset))
}

func dayLabel(d string) string {
	t, _ := time.Parse("2006-01-02", d)
	now := time.Now()
	today := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, time.UTC)
	switch {
	case t.Equal(today):
		return "Today"
	case t.Equal(today.Add(24 * time.Hour)):
		return "Tomorrow"
	default:
		return t.Weekday().String()[:3]
	}
}

func fmtTime(t string) string {
	t = fmt.Sprintf("%04s", t)
	return t[:2] + ":" + t[2:]
}

func icon(condition string, night bool) string {
	c := strings.ToLower(condition)
	switch {
	case strings.Contains(c, "clear") || strings.Contains(c, "sun"):
		if night {
			return "clear_night"
		}
		return "partly_cloudy_day"
	case strings.Contains(c, "partly"):
		if night {
			return "cloudy"
		}
		return "partly_cloudy_day"
	case strings.Contains(c, "cloud") || strings.Contains(c, "overcast"):
		return "cloud"
	case strings.Contains(c, "fog") || strings.Contains(c, "mist"):
		return "foggy"
	case strings.Contains(c, "rain") || strings.Contains(c, "drizzle"):
		return "rainy"
	case strings.Contains(c, "snow"):
		return "ac_unit"
	case strings.Contains(c, "thunder"):
		return "thunderstorm"
	default:
		return "cloudy"
	}
}

func lock() (*os.File, error) {
	fh, err := os.OpenFile(lockPath, os.O_CREATE|os.O_RDWR, 0644)
	if err != nil {
		return nil, err
	}
	if err := syscall.Flock(int(fh.Fd()), syscall.LOCK_EX|syscall.LOCK_NB); err != nil {
		fh.Seek(0, 0)
		b := make([]byte, 16)
		n, _ := fh.Read(b)
		if pid, err := strconv.Atoi(strings.TrimSpace(string(b[:n]))); err == nil && pid > 0 {
			syscall.Kill(pid, syscall.SIGKILL) 
		}
		
		if err := syscall.Flock(int(fh.Fd()), syscall.LOCK_EX); err != nil {
			fh.Close()
			return nil, err
		}
	}
	fh.Truncate(0)
	fh.Seek(0, 0)
	fh.WriteString(strconv.Itoa(os.Getpid()))
	fh.Sync()
	return fh, nil
}

func fetch(city string, fahrenheit bool) (map[string]any, error) {
	req, err := http.NewRequest("GET", api+"/"+url.PathEscape(city)+"?format=j1", nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("User-Agent", ua)
	resp, err := http.DefaultClient.Do(req) 
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != 200 {
		return nil, fmt.Errorf("http %d", resp.StatusCode)
	}

	var d wttr
	if err := json.NewDecoder(resp.Body).Decode(&d); err != nil {
		return nil, err
	}

	cur := d.CurrentCondition[0]
	area := d.NearestArea[0]
	unit := "C"
	if fahrenheit {
		unit = "F"
	}

	location := area.AreaName[0].Value
	if area.Country[0].Value != "" {
		location += ", " + area.Country[0].Value
	}

	wind, _ := strconv.Atoi(cur.WindspeedKmph)
	vis, _ := strconv.Atoi(cur.Visibility)
	windUnit, visUnit := "km/h", "km"
	if fahrenheit {
		wind = int(float64(wind) * 0.621371 + 0.5)
		vis = int(float64(vis) * 0.621371 + 0.5)
		windUnit, visUnit = "mph", "mi"
	}

	forecast := make([]map[string]any, 0, len(d.Weather))
	for _, wd := range d.Weather { 
		a := wd.Astronomy[0]
		hs := make([]map[string]any, 0, len(wd.Hourly))
		for _, h := range wd.Hourly {
			t := fmtTime(h.Time)
			cond := h.WeatherDesc[0].Value
			temp := h.TempC
			if fahrenheit {
				temp = h.TempF
			}
			hs = append(hs, map[string]any{
				"time": t, "temp": deg(temp, unit), "condition": cond,
				"emoji":            icon(cond, isNight(t, a.Sunrise, a.Sunset)),
				"chance_of_rain":   h.ChanceOfRain + "%",
			})
		}
		noon := wd.Hourly[4] 
		hi, _ := strconv.Atoi(wd.MaxtempC)
		lo, _ := strconv.Atoi(wd.MintempC)
		if fahrenheit {
			hi, _ = strconv.Atoi(wd.MaxtempF)
			lo, _ = strconv.Atoi(wd.MintempF)
		}
		forecast = append(forecast, map[string]any{
			"date": dayLabel(wd.Date), "max_temp": deg(strconv.Itoa(hi), unit),
			"min_temp": deg(strconv.Itoa(lo), unit), "avg_temp": deg(strconv.Itoa((hi+lo)/2), unit),
			"condition": noon.WeatherDesc[0].Value, "emoji": icon(noon.WeatherDesc[0].Value, false),
			"sunrise": a.Sunrise, "sunset": a.Sunset,
			"uv_index": orDefault(wd.UVIndex, "N/A"), "chance_of_rain": noon.ChanceOfRain + "%",
			"hourly": hs,
		})
	}

	condition := cur.WeatherDesc[0].Value
	curTemp, curFeels := cur.TempC, cur.FeelsLikeC
	if fahrenheit {
		curTemp, curFeels = cur.TempF, cur.FeelsLikeF
	}
	
	astro := d.Weather[0].Astronomy[0]
	night := isNight(time.Now().Format("15:04"), astro.Sunrise, astro.Sunset)

	return map[string]any{
		"location": location, "sunrise": astro.Sunrise, "sunset": astro.Sunset,
		"current_temp": deg(curTemp, unit), "current_emoji": icon(condition, night),
		"current_condition": condition, "feels_like": deg(curFeels, unit),
		"humidity": cur.Humidity + "%", "wind_speed": strconv.Itoa(wind) + " " + windUnit,
		"visibility": strconv.Itoa(vis) + " " + visUnit, "forecast": forecast,
	}, nil
}

func orDefault(v, d string) string {
	if v == "" {
		return d
	}
	return v
}

func check(ok bool, msg string) {
	if !ok {
		fmt.Println("selftest FAIL:", msg)
		os.Exit(1)
	}
}

func selftest() {
	check(timeMin("06:30 AM").Equal(timeMin("06:30")), "12h==24h")
	check(timeMin("12:30 PM").Equal(timeMin("12:30")), "noon")
	check(isNight("02:00", "06:00", "19:00") && !isNight("12:00", "06:00", "19:00"), "isNight")
	check(dayLabel(time.Now().Format("2006-01-02")) == "Today", "dayLabel today")
	check(fmtTime("0") == "00:00" && fmtTime("900") == "09:00" && fmtTime("1200") == "12:00", "fmtTime")
	check(icon("Partly cloudy", false) == "partly_cloudy_day", "icon partly")
	check(icon("Sunny", false) == "partly_cloudy_day", "icon sunny")
	check(icon("Light rain", true) == "rainy", "icon rain")
	fmt.Println("selftest OK")
}

func main() {
	defer func() {
		if r := recover(); r != nil {
			fmt.Printf(`{"error": %q}`, r) 
		}
	}()
	city := flag.String("city", "", "")
	shortCity := flag.String("c", "", "")
	fahrenheit := flag.Bool("fahrenheit", false, "")
	shortFahrenheit := flag.Bool("f", false, "")
	selftestFlag := flag.Bool("selftest", false, "")
	flag.Parse()

	if *selftestFlag {
		selftest()
		return
	}
	c := *city
	if c == "" {
		c = *shortCity
	}
	if c == "" {
		c = flag.Arg(0)
	}
	if c == "" {
		fmt.Println(`{"error": "Usage: weather_service <city | --city <city>> [--fahrenheit]"}`)
		os.Exit(1)
	}

	fh, err := lock()
	if err != nil {
		fmt.Printf(`{"error": %q}`, err.Error())
		return
	}
	defer fh.Close()
	w, err := fetch(c, *fahrenheit || *shortFahrenheit)
	if err != nil {
		fmt.Printf(`{"error": %q}`, err.Error())
		return
	}
	out, _ := json.Marshal(w)
	fmt.Println(string(out))
}
