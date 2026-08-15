package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"net/http"
	"net/url"
	"os"
	"regexp"
	"strconv"
	"strings"
	"syscall"
	"time"
)

const (
	forecastAPI = "https://api.met.no/weatherapi/locationforecast/2.0/complete"
	sunAPI      = "https://api.met.no/weatherapi/sunrise/3.0/sun"
	geocodeAPI  = "https://geocoding-api.open-meteo.com/v1/search"
	ua          = "weather_service_met/1.0 (contact: cdumb@proton.me)"
	lockPath    = "/tmp/weather_service_met.lock"
)

type geoHit struct {
	Name      string  `json:"name"`
	Country   string  `json:"country"`
	Admin1    string  `json:"admin1"`
	Latitude  float64 `json:"latitude"`
	Longitude float64 `json:"longitude"`
}

type geoResponse struct {
	Results []geoHit `json:"results"`
}

type instantDetails struct {
	AirPressureAtSeaLevel float64 `json:"air_pressure_at_sea_level"`
	AirTemperature        float64 `json:"air_temperature"`
	CloudAreaFraction     float64 `json:"cloud_area_fraction"`
	DewPointTemperature   float64 `json:"dew_point_temperature"`
	FogAreaFraction       float64 `json:"fog_area_fraction"`
	RelativeHumidity      float64 `json:"relative_humidity"`
	UVIndexClearSky       float64 `json:"ultraviolet_index_clear_sky"`
	WindFromDirection     float64 `json:"wind_from_direction"`
	WindSpeed             float64 `json:"wind_speed"`
	WindSpeedGust         float64 `json:"wind_speed_of_gust"`
}

type periodDetails struct {
	PrecipitationAmount        float64 `json:"precipitation_amount"`
	ProbabilityOfPrecipitation float64 `json:"probability_of_precipitation"`
	ProbabilityOfThunder       float64 `json:"probability_of_thunder"`
}

type periodSummary struct {
	SymbolCode string `json:"symbol_code"`
}

type period struct {
	Summary periodSummary `json:"summary"`
	Details periodDetails `json:"details"`
}

type timestepData struct {
	Instant struct {
		Details instantDetails `json:"details"`
	} `json:"instant"`
	Next1Hours  *period `json:"next_1_hours,omitempty"`
	Next6Hours  *period `json:"next_6_hours,omitempty"`
	Next12Hours *period `json:"next_12_hours,omitempty"`
}

type timestep struct {
	Time string       `json:"time"`
	Data timestepData `json:"data"`
}

type forecastResponse struct {
	Properties struct {
		Timeseries []timestep `json:"timeseries"`
	} `json:"properties"`
}

type sunResponse struct {
	Properties struct {
		Sunrise struct {
			Time string `json:"time"`
		} `json:"sunrise"`
		Sunset struct {
			Time string `json:"time"`
		} `json:"sunset"`
	} `json:"properties"`
}

func degSym(v float64, unit string) string { return fmt.Sprintf("%.0f°%s", v, unit) }

func cToF(c float64) float64 { return c*9/5 + 32 }

func msToKmh(ms float64) float64 { return ms * 3.6 }

func msToMph(ms float64) float64 { return ms * 2.23694 }

func kmToMi(km float64) float64 { return km * 0.621371 }

func compass(deg float64) string {
	dirs := []string{"N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE", "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"}
	idx := int((deg/22.5)+0.5) % 16
	if idx < 0 {
		idx += 16
	}
	return dirs[idx]
}

func feelsLikeC(tempC, windMs, humidity float64) float64 {
	if tempC <= 10 && windMs > 1.34 {
		windKmh := msToKmh(windMs)
		return 13.12 + 0.6215*tempC - 11.37*mathPow(windKmh, 0.16) + 0.3965*tempC*mathPow(windKmh, 0.16)
	}
	if tempC >= 27 && humidity >= 40 {
		return -8.784 + 1.611*tempC + 2.339*humidity - 0.146*tempC*humidity
	}
	return tempC
}

func mathPow(base, exp float64) float64 {
	if base <= 0 {
		return 0
	}
	result := 1.0
	steps := 64
	logBase := logApprox(base)
	x := exp * logBase
	term := 1.0
	for i := 1; i <= steps; i++ {
		term *= x / float64(i)
		result += term
	}
	return result
}

func logApprox(x float64) float64 {
	if x <= 0 {
		return 0
	}
	y := (x - 1) / (x + 1)
	sum := 0.0
	term := y
	for i := 1; i <= 40; i += 2 {
		sum += term / float64(i)
		term *= y * y
	}
	return 2 * sum
}

func parseISO(s string) time.Time {
	t, _ := time.Parse(time.RFC3339, s)
	return t.Local()
}

func fmtClock(t time.Time) string { return t.Format("15:04") }

func dayLabel(d string) string {
	t, _ := time.Parse("2006-01-02", d)
	now := time.Now()
	today := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, time.Local)
	switch {
	case t.Equal(today):
		return "Today"
	case t.Equal(today.Add(24 * time.Hour)):
		return "Tomorrow"
	default:
		return t.Weekday().String()[:3]
	}
}

func isNight(t, sunrise, sunset time.Time) bool {
	if sunrise.IsZero() || sunset.IsZero() {
		return t.Hour() < 6 || t.Hour() >= 20
	}
	return t.Before(sunrise) || t.After(sunset)
}

var suffixPattern = regexp.MustCompile(`_(day|night|polartwilight)$`)

var tokenPattern = regexp.MustCompile(`partlycloudy|clearsky|cloudy|fair|fog|heavy|light|showers|thunder|rain|snow|sleet|and`)

func conditionTokens(code string) []string {
	c := suffixPattern.ReplaceAllString(strings.ToLower(code), "")
	return tokenPattern.FindAllString(c, -1)
}

var iconPriority = []string{"thunder", "snow", "sleet", "fog", "rain", "showers", "partlycloudy", "clearsky", "fair", "cloudy"}

var dayIcons = map[string]string{
	"clearsky": "partly_cloudy_day", "fair": "partly_cloudy_day", "partlycloudy": "partly_cloudy_day",
	"cloudy": "cloud", "fog": "foggy", "thunder": "thunderstorm", "sleet": "weather_mix",
	"snow": "ac_unit", "rain": "rainy", "showers": "rainy",
}

var nightIcons = map[string]string{
	"clearsky": "clear_night", "fair": "clear_night", "partlycloudy": "cloudy",
	"cloudy": "cloud", "fog": "foggy", "thunder": "thunderstorm", "sleet": "weather_mix",
	"snow": "ac_unit", "rain": "rainy", "showers": "rainy",
}

var dayEmojis = map[string]string{
	"clearsky": "☀️", "fair": "⛅", "partlycloudy": "⛅", "cloudy": "☁️",
	"fog": "🌫️", "thunder": "⛈️", "sleet": "🌧️", "snow": "❄️", "rain": "🌧️", "showers": "🌦️",
}

var nightEmojis = map[string]string{
	"clearsky": "🌙", "fair": "🌙", "partlycloudy": "☁️", "cloudy": "☁️",
	"fog": "🌫️", "thunder": "⛈️", "sleet": "🌧️", "snow": "❄️", "rain": "🌧️", "showers": "🌦️",
}

func conditionValue(code string, night bool, day, nightMap map[string]string, fallback string) string {
	m := day
	if night {
		m = nightMap
	}
	set := make(map[string]bool)
	for _, w := range conditionTokens(code) {
		set[w] = true
	}
	for _, key := range iconPriority {
		if set[key] {
			return m[key]
		}
	}
	return fallback
}

func symbolIcon(code string, night bool) string {
	return conditionValue(code, night, dayIcons, nightIcons, "cloudy")
}

func symbolEmoji(code string, night bool) string {
	return conditionValue(code, night, dayEmojis, nightEmojis, "🌥️")
}

var labelExpansions = map[string]string{
	"clearsky":     "clear sky",
	"partlycloudy": "partly cloudy",
}

func conditionLabel(code string) string {
	words := conditionTokens(code)
	if len(words) == 0 {
		return "Unknown"
	}
	parts := make([]string, len(words))
	for i, w := range words {
		if expanded, ok := labelExpansions[w]; ok {
			parts[i] = expanded
		} else {
			parts[i] = w
		}
	}
	label := strings.Join(parts, " ")
	return strings.ToUpper(label[:1]) + label[1:]
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

func httpGetJSON(stage, rawURL string, out any) error {
	req, err := http.NewRequest("GET", rawURL, nil)
	if err != nil {
		return fmt.Errorf("%s: %w", stage, err)
	}
	req.Header.Set("User-Agent", ua)
	req.Header.Set("Accept", "application/json")
	client := &http.Client{Timeout: 15 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return fmt.Errorf("%s: %w", stage, err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != 200 {
		body := make([]byte, 512)
		n, _ := resp.Body.Read(body)
		return fmt.Errorf("%s: http %d: %s", stage, resp.StatusCode, strings.TrimSpace(string(body[:n])))
	}
	return json.NewDecoder(resp.Body).Decode(out)
}

func geocode(city string) (lat, lon, name string, err error) {
	q := url.Values{}
	q.Set("name", city)
	q.Set("count", "1")
	q.Set("format", "json")
	var gr geoResponse
	if err = httpGetJSON("geocode", geocodeAPI+"?"+q.Encode(), &gr); err != nil {
		return "", "", "", err
	}
	if len(gr.Results) == 0 {
		return "", "", "", fmt.Errorf("no location found for %q", city)
	}
	hit := gr.Results[0]
	location := hit.Name
	if hit.Admin1 != "" {
		location += ", " + hit.Admin1
	}
	if hit.Country != "" {
		location += ", " + hit.Country
	}
	return strconv.FormatFloat(hit.Latitude, 'f', 4, 64), strconv.FormatFloat(hit.Longitude, 'f', 4, 64), location, nil
}

func fetchForecast(lat, lon string) (*forecastResponse, error) {
	q := url.Values{}
	q.Set("lat", lat)
	q.Set("lon", lon)
	var fr forecastResponse
	if err := httpGetJSON("forecast", forecastAPI+"?"+q.Encode(), &fr); err != nil {
		return nil, err
	}
	if len(fr.Properties.Timeseries) == 0 {
		return nil, fmt.Errorf("empty forecast response")
	}
	return &fr, nil
}

func fetchSun(lat, lon string, date time.Time) (sunrise, sunset time.Time, err error) {
	q := url.Values{}
	q.Set("lat", lat)
	q.Set("lon", lon)
	q.Set("date", date.Format("2006-01-02"))
	var sr sunResponse
	if err = httpGetJSON("sun", sunAPI+"?"+q.Encode(), &sr); err != nil {
		return time.Time{}, time.Time{}, err
	}
	sunrise = parseISO(sr.Properties.Sunrise.Time)
	sunset = parseISO(sr.Properties.Sunset.Time)
	return sunrise, sunset, nil
}

func periodFor(d timestepData) *period {
	if d.Next1Hours != nil {
		return d.Next1Hours
	}
	if d.Next6Hours != nil {
		return d.Next6Hours
	}
	return d.Next12Hours
}

func buildHourly(ts []timestep, date string, fahrenheit bool, sunrise, sunset time.Time, unit string) []map[string]any {
	hs := make([]map[string]any, 0)
	for _, step := range ts {
		t := parseISO(step.Time)
		if t.Format("2006-01-02") != date {
			continue
		}
		p := periodFor(step.Data)
		condition := "unknown"
		precip := 0.0
		pop := -1.0
		if p != nil {
			condition = p.Summary.SymbolCode
			precip = p.Details.PrecipitationAmount
			pop = p.Details.ProbabilityOfPrecipitation
		}
		details := step.Data.Instant.Details
		temp := details.AirTemperature
		if fahrenheit {
			temp = cToF(temp)
		}
		wind := details.WindSpeed
		if fahrenheit {
			wind = msToMph(wind)
		} else {
			wind = msToKmh(wind)
		}
		entry := map[string]any{
			"time":             fmtClock(t),
			"temp":             degSym(temp, unit),
			"condition":        conditionLabel(condition),
			"emoji":            symbolEmoji(condition, isNight(t, sunrise, sunset)),
			"material_icon":    symbolIcon(condition, isNight(t, sunrise, sunset)),
			"wind_speed":       fmt.Sprintf("%.0f", wind),
			"wind_direction":   compass(details.WindFromDirection),
			"precipitation_mm": fmt.Sprintf("%.1f", precip),
		}
		if pop >= 0 {
			entry["chance_of_rain"] = fmt.Sprintf("%.0f%%", pop)
		} else {
			entry["chance_of_rain"] = "N/A"
		}
		hs = append(hs, entry)
	}
	return hs
}

func fetch(city string, fahrenheit bool) (map[string]any, error) {
	lat, lon, location, err := geocode(city)
	if err != nil {
		return nil, err
	}
	fr, err := fetchForecast(lat, lon)
	if err != nil {
		return nil, err
	}
	ts := fr.Properties.Timeseries

	unit := "C"
	if fahrenheit {
		unit = "F"
	}
	windUnit := "km/h"
	if fahrenheit {
		windUnit = "mph"
	}

	now := parseISO(ts[0].Time)
	todaySunrise, todaySunset, _ := fetchSun(lat, lon, now)

	dates := make([]string, 0, 3)
	seen := map[string]bool{}
	for _, step := range ts {
		d := parseISO(step.Time).Format("2006-01-02")
		if !seen[d] {
			seen[d] = true
			dates = append(dates, d)
			if len(dates) == 3 {
				break
			}
		}
	}

	forecast := make([]map[string]any, 0, len(dates))
	for _, date := range dates {
		dSunrise, dSunset, serr := fetchSun(lat, lon, mustParseDate(date))
		if serr != nil {
			dSunrise, dSunset = todaySunrise, todaySunset
		}

		var maxT, minT float64
		first := true
		var noon *timestep
		var noonDiff time.Duration = -1
		var uv, pressure, cloud, gust, windDirSum float64
		var windDirCount int
		var pop float64 = -1

		for i := range ts {
			t := parseISO(ts[i].Time)
			if t.Format("2006-01-02") != date {
				continue
			}
			det := ts[i].Data.Instant.Details
			if first {
				maxT, minT = det.AirTemperature, det.AirTemperature
				first = false
			} else {
				if det.AirTemperature > maxT {
					maxT = det.AirTemperature
				}
				if det.AirTemperature < minT {
					minT = det.AirTemperature
				}
			}
			if det.UVIndexClearSky > uv {
				uv = det.UVIndexClearSky
			}
			pressure += det.AirPressureAtSeaLevel
			cloud += det.CloudAreaFraction
			if det.WindSpeedGust > gust {
				gust = det.WindSpeedGust
			}
			windDirSum += det.WindFromDirection
			windDirCount++

			noonTarget := time.Date(t.Year(), t.Month(), t.Day(), 12, 0, 0, 0, t.Location())
			diff := t.Sub(noonTarget)
			if diff < 0 {
				diff = -diff
			}
			if noonDiff == -1 || diff < noonDiff {
				noonDiff = diff
				step := ts[i]
				noon = &step
				if p := periodFor(step.Data); p != nil {
					pop = p.Details.ProbabilityOfPrecipitation
				}
			}
		}
		if windDirCount > 0 {
			pressure /= float64(windDirCount)
			cloud /= float64(windDirCount)
			windDirSum /= float64(windDirCount)
		}

		condition := "unknown"
		if noon != nil {
			if p := periodFor(noon.Data); p != nil {
				condition = p.Summary.SymbolCode
			}
		}

		hi, lo := maxT, minT
		if fahrenheit {
			hi, lo = cToF(hi), cToF(lo)
		}

		chanceOfRain := "N/A"
		if pop >= 0 {
			chanceOfRain = fmt.Sprintf("%.0f%%", pop)
		}

		forecast = append(forecast, map[string]any{
			"date":           dayLabel(date),
			"max_temp":       degSym(hi, unit),
			"min_temp":       degSym(lo, unit),
			"avg_temp":       degSym((hi+lo)/2, unit),
			"condition":      conditionLabel(condition),
			"emoji":          symbolEmoji(condition, false),
			"material_icon":  symbolIcon(condition, false),
			"sunrise":        fmtClock(dSunrise),
			"sunset":         fmtClock(dSunset),
			"uv_index":       fmt.Sprintf("%.1f", uv),
			"pressure_hpa":   fmt.Sprintf("%.0f", pressure),
			"cloud_cover":    fmt.Sprintf("%.0f%%", cloud),
			"wind_gust":      fmt.Sprintf("%.0f %s", condWindUnit(gust, fahrenheit), windUnit),
			"wind_direction": compass(windDirSum),
			"chance_of_rain": chanceOfRain,
			"hourly":         buildHourly(ts, date, fahrenheit, dSunrise, dSunset, unit),
		})
	}

	curDetails := ts[0].Data.Instant.Details
	curTemp := curDetails.AirTemperature
	feels := feelsLikeC(curDetails.AirTemperature, curDetails.WindSpeed, curDetails.RelativeHumidity)
	if fahrenheit {
		curTemp = cToF(curTemp)
		feels = cToF(feels)
	}
	curCondition := "unknown"
	if p := periodFor(ts[0].Data); p != nil {
		curCondition = p.Summary.SymbolCode
	}
	night := isNight(now, todaySunrise, todaySunset)
	curWind := condWindUnit(curDetails.WindSpeed, fahrenheit)
	curGust := condWindUnit(curDetails.WindSpeedGust, fahrenheit)

	return map[string]any{
		"location":          location,
		"sunrise":           fmtClock(todaySunrise),
		"sunset":            fmtClock(todaySunset),
		"current_temp":      degSym(curTemp, unit),
		"current_emoji":     symbolEmoji(curCondition, night),
		"material_icon":     symbolIcon(curCondition, night),
		"current_condition": conditionLabel(curCondition),
		"feels_like":        degSym(feels, unit),
		"humidity":          fmt.Sprintf("%.0f%%", curDetails.RelativeHumidity),
		"dew_point":         degSym(condTemp(curDetails.DewPointTemperature, fahrenheit), unit),
		"wind_speed":        fmt.Sprintf("%.0f %s", curWind, windUnit),
		"wind_direction":    compass(curDetails.WindFromDirection),
		"wind_gust":         fmt.Sprintf("%.0f %s", curGust, windUnit),
		"pressure_hpa":      fmt.Sprintf("%.0f", curDetails.AirPressureAtSeaLevel),
		"cloud_cover":       fmt.Sprintf("%.0f%%", curDetails.CloudAreaFraction),
		"fog_area_fraction": fmt.Sprintf("%.0f%%", curDetails.FogAreaFraction),
		"uv_index":          fmt.Sprintf("%.1f", curDetails.UVIndexClearSky),
		"forecast":          forecast,
	}, nil
}

func condTemp(c float64, fahrenheit bool) float64 {
	if fahrenheit {
		return cToF(c)
	}
	return c
}

func condWindUnit(ms float64, fahrenheit bool) float64 {
	if fahrenheit {
		return msToMph(ms)
	}
	return msToKmh(ms)
}

func mustParseDate(d string) time.Time {
	t, _ := time.Parse("2006-01-02", d)
	return t
}

func check(ok bool, msg string) {
	if !ok {
		fmt.Println("selftest FAIL:", msg)
		os.Exit(1)
	}
}

func selftest() {
	check(compass(0) == "N", "compass N")
	check(compass(90) == "E", "compass E")
	check(compass(180) == "S", "compass S")
	check(compass(270) == "W", "compass W")
	check(compass(360) == "N", "compass wrap")
	check(symbolIcon("clearsky_day", false) == "partly_cloudy_day", "icon clearsky_day")
	check(symbolIcon("clearsky_night", true) == "clear_night", "icon clearsky_night")
	check(symbolIcon("lightrain", false) == "rainy", "icon rain")
	check(symbolIcon("heavysnow", false) == "ac_unit", "icon snow")
	check(symbolEmoji("clearsky_day", false) == "☀️", "emoji clearsky_day")
	check(symbolEmoji("clearsky_night", true) == "🌙", "emoji clearsky_night")
	check(symbolEmoji("lightrain", false) == "🌧️", "emoji rain")
	check(symbolEmoji("heavysnow", false) == "❄️", "emoji snow")
	check(dayLabel(time.Now().Format("2006-01-02")) == "Today", "dayLabel today")
	feels := feelsLikeC(-5, 10, 50)
	check(feels < -5, "windchill lowers feel")
	fmt.Println("selftest OK")
}

func main() {
	defer func() {
		if r := recover(); r != nil {
			fmt.Printf(`{"error": %q}`, fmt.Sprint(r))
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
		fmt.Println(`{"error": "Usage: weather_service_met <city | --city <city>> [--fahrenheit]"}`)
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
