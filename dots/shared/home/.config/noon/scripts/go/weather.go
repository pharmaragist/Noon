package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"math"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"syscall"
	"time"
)

const (
	forecastAPI  = "https://api.met.no/weatherapi/locationforecast/2.0/complete"
	sunAPI       = "https://api.met.no/weatherapi/sunrise/3.0/sun"
	geocodeAPI   = "https://geocoding-api.open-meteo.com/v1/search"
	userAgent    = "weather_service/1.0 (contact: cdumb@proton.me)"
	lockPath     = "/tmp/weather_service.lock"
	forecastDays = 3
	httpTimeout  = 15 * time.Second
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

type HourlyEntry struct {
	Time            string `json:"time"`
	Temp            string `json:"temp"`
	Condition       string `json:"condition"`
	Emoji           string `json:"emoji"`
	MaterialIcon    string `json:"material_icon"`
	WindSpeed       string `json:"wind_speed"`
	WindDirection   string `json:"wind_direction"`
	PrecipitationMM string `json:"precipitation_mm"`
	ChanceOfRain    string `json:"chance_of_rain"`
}

type DailyForecast struct {
	Date          string        `json:"date"`
	MaxTemp       string        `json:"max_temp"`
	MinTemp       string        `json:"min_temp"`
	AvgTemp       string        `json:"avg_temp"`
	Condition     string        `json:"condition"`
	Emoji         string        `json:"emoji"`
	MaterialIcon  string        `json:"material_icon"`
	Sunrise       string        `json:"sunrise"`
	Sunset        string        `json:"sunset"`
	UVIndex       string        `json:"uv_index"`
	PressureHPa   string        `json:"pressure_hpa"`
	CloudCover    string        `json:"cloud_cover"`
	WindGust      string        `json:"wind_gust"`
	WindDirection string        `json:"wind_direction"`
	ChanceOfRain  string        `json:"chance_of_rain"`
	Hourly        []HourlyEntry `json:"hourly"`
}

type WeatherResult struct {
	Error            string          `json:"error,omitempty"`
	Location         string          `json:"location"`
	Date             string          `json:"date"`
	Daytime          bool            `json:"daytime"`
	Sunrise          string          `json:"sunrise"`
	Sunset           string          `json:"sunset"`
	CurrentTemp      string          `json:"current_temp"`
	CurrentEmoji     string          `json:"current_emoji"`
	MaterialIcon     string          `json:"material_icon"`
	CurrentCondition string          `json:"current_condition"`
	FeelsLike        string          `json:"feels_like"`
	Humidity         string          `json:"humidity"`
	DewPoint         string          `json:"dew_point"`
	WindSpeed        string          `json:"wind_speed"`
	WindDirection    string          `json:"wind_direction"`
	WindGust         string          `json:"wind_gust"`
	PressureHPa      string          `json:"pressure_hpa"`
	CloudCover       string          `json:"cloud_cover"`
	FogAreaFraction  string          `json:"fog_area_fraction"`
	UVIndex          string          `json:"uv_index"`
	Forecast         []DailyForecast `json:"forecast"`
}

type Units struct {
	TempSymbol  string
	SpeedSymbol string
	Temp        func(float64) float64
	Speed       func(float64) float64
}

func identity(v float64) float64 { return v }

func unitsFor(fahrenheit bool) Units {
	if fahrenheit {
		return Units{TempSymbol: "F", SpeedSymbol: "mph", Temp: cToF, Speed: msToMph}
	}
	return Units{TempSymbol: "C", SpeedSymbol: "km/h", Temp: identity, Speed: msToKmh}
}

func degSym(v float64, unit string) string { return fmt.Sprintf("%.0f°%s", v, unit) }
func cToF(c float64) float64               { return c*9/5 + 32 }
func msToKmh(ms float64) float64           { return ms * 3.6 }
func msToMph(ms float64) float64           { return ms * 2.23694 }

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
		return 13.12 + 0.6215*tempC - 11.37*math.Pow(windKmh, 0.16) + 0.3965*tempC*math.Pow(windKmh, 0.16)
	}
	if tempC >= 27 && humidity >= 40 {
		return -8.784 + 1.611*tempC + 2.339*humidity - 0.146*tempC*humidity
	}
	return tempC
}

func parseISO(s string) time.Time {
	t, _ := time.Parse(time.RFC3339, s)
	return t.Local()
}

func fmtClock(t time.Time) string { return t.Format("15:04") }

func dayLabelAt(d string, now time.Time) string {
	t, _ := time.Parse("2006-01-02", d)
	now = now.In(t.Location())
	today := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, now.Location())
	tomorrow := today.AddDate(0, 0, 1)
	tm := t.Year()*10000 + int(t.Month())*100 + t.Day()
	td := today.Year()*10000 + int(today.Month())*100 + today.Day()
	tr := tomorrow.Year()*10000 + int(tomorrow.Month())*100 + tomorrow.Day()
	switch {
	case tm == td:
		return "Today"
	case tm == tr:
		return "Tomorrow"
	default:
		return t.Weekday().String()[:3]
	}
}

func dayLabel(d string) string { return dayLabelAt(d, time.Now()) }

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

type conditionVisual struct {
	dayIcon, nightIcon, dayEmoji, nightEmoji string
}

var iconPriority = []string{"thunder", "snow", "sleet", "fog", "rain", "showers", "partlycloudy", "clearsky", "fair", "cloudy"}

var conditionVisuals = map[string]conditionVisual{
	"clearsky":     {"partly_cloudy_day", "clear_night", "☀️", "🌙"},
	"fair":         {"partly_cloudy_day", "clear_night", "⛅", "🌙"},
	"partlycloudy": {"partly_cloudy_day", "cloudy", "⛅", "☁️"},
	"cloudy":       {"cloud", "cloud", "☁️", "☁️"},
	"fog":          {"foggy", "foggy", "🌫️", "🌫️"},
	"thunder":      {"thunderstorm", "thunderstorm", "⛈️", "⛈️"},
	"sleet":        {"weather_mix", "weather_mix", "🌧️", "🌧️"},
	"snow":         {"ac_unit", "ac_unit", "❄️", "❄️"},
	"rain":         {"rainy", "rainy", "🌧️", "🌧️"},
	"showers":      {"rainy", "rainy", "🌦️", "🌦️"},
}

func visualFor(code string) (conditionVisual, bool) {
	set := make(map[string]bool)
	for _, w := range conditionTokens(code) {
		set[w] = true
	}
	for _, key := range iconPriority {
		if set[key] {
			return conditionVisuals[key], true
		}
	}
	return conditionVisual{}, false
}

func symbolIcon(code string, night bool) string {
	v, ok := visualFor(code)
	if !ok {
		return "cloudy"
	}
	if night {
		return v.nightIcon
	}
	return v.dayIcon
}

func symbolEmoji(code string, night bool) string {
	v, ok := visualFor(code)
	if !ok {
		return "🌥️"
	}
	if night {
		return v.nightEmoji
	}
	return v.dayEmoji
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

func readLockPID(fh *os.File) (int, bool) {
	fh.Seek(0, 0)
	b := make([]byte, 16)
	n, _ := fh.Read(b)
	pid, err := strconv.Atoi(strings.TrimSpace(string(b[:n])))
	return pid, err == nil && pid > 0
}

func samePIDProcess(pid int) bool {
	self, err := os.Executable()
	if err != nil {
		return false
	}
	comm, err := os.ReadFile(fmt.Sprintf("/proc/%d/comm", pid))
	if err != nil {
		return false
	}
	name := strings.TrimSpace(string(comm))
	base := filepath.Base(self)
	if len(base) > len(name) {
		base = base[:len(name)]
	}
	return base == name
}

func acquireLock() (*os.File, error) {
	fh, err := os.OpenFile(lockPath, os.O_CREATE|os.O_RDWR, 0644)
	if err != nil {
		return nil, err
	}
	if err := syscall.Flock(int(fh.Fd()), syscall.LOCK_EX|syscall.LOCK_NB); err != nil {
		if pid, ok := readLockPID(fh); ok && samePIDProcess(pid) {
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
	req.Header.Set("User-Agent", userAgent)
	req.Header.Set("Accept", "application/json")
	client := &http.Client{Timeout: httpTimeout}
	resp, err := client.Do(req)
	if err != nil {
		return fmt.Errorf("%s: %w", stage, err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(io.LimitReader(resp.Body, 512))
		return fmt.Errorf("%s: http %d: %s", stage, resp.StatusCode, strings.TrimSpace(string(body)))
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

func chanceString(pop float64) string {
	if pop >= 0 {
		return fmt.Sprintf("%.0f%%", pop)
	}
	return "N/A"
}

func groupByDate(ts []timestep, limit int) ([]string, map[string][]timestep) {
	grouped := make(map[string][]timestep)
	dates := make([]string, 0, limit)
	for _, step := range ts {
		d := parseISO(step.Time).Format("2006-01-02")
		if _, exists := grouped[d]; !exists {
			if len(dates) == limit {
				break
			}
			dates = append(dates, d)
		}
		grouped[d] = append(grouped[d], step)
	}
	return dates, grouped
}

func mustParseDate(d string) time.Time {
	t, _ := time.Parse("2006-01-02", d)
	return t
}

func buildDailyForecast(date string, steps []timestep, sunrise, sunset time.Time, u Units) DailyForecast {
	var maxT, minT, uv, pressureSum, cloudSum, gust, windDirSum float64
	var windDirCount int
	first := true
	var noonDiff time.Duration = -1
	noonCondition := "unknown"
	noonPop := -1.0
	hourly := make([]HourlyEntry, 0, len(steps))

	for _, step := range steps {
		t := parseISO(step.Time)
		det := step.Data.Instant.Details
		p := periodFor(step.Data)

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
		pressureSum += det.AirPressureAtSeaLevel
		cloudSum += det.CloudAreaFraction
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

		condition := "unknown"
		precip, pop := 0.0, -1.0
		if p != nil {
			condition = p.Summary.SymbolCode
			precip = p.Details.PrecipitationAmount
			pop = p.Details.ProbabilityOfPrecipitation
		}

		if noonDiff == -1 || diff < noonDiff {
			noonDiff = diff
			noonCondition = condition
			noonPop = pop
		}

		night := isNight(t, sunrise, sunset)
		hourly = append(hourly, HourlyEntry{
			Time:            fmtClock(t),
			Temp:            degSym(u.Temp(det.AirTemperature), u.TempSymbol),
			Condition:       conditionLabel(condition),
			Emoji:           symbolEmoji(condition, night),
			MaterialIcon:    symbolIcon(condition, night),
			WindSpeed:       fmt.Sprintf("%.0f", u.Speed(det.WindSpeed)),
			WindDirection:   compass(det.WindFromDirection),
			PrecipitationMM: fmt.Sprintf("%.1f", precip),
			ChanceOfRain:    chanceString(pop),
		})
	}

	if windDirCount > 0 {
		pressureSum /= float64(windDirCount)
		cloudSum /= float64(windDirCount)
		windDirSum /= float64(windDirCount)
	}

	hi, lo := u.Temp(maxT), u.Temp(minT)
	return DailyForecast{
		Date:          dayLabel(date),
		MaxTemp:       degSym(hi, u.TempSymbol),
		MinTemp:       degSym(lo, u.TempSymbol),
		AvgTemp:       degSym((hi+lo)/2, u.TempSymbol),
		Condition:     conditionLabel(noonCondition),
		Emoji:         symbolEmoji(noonCondition, false),
		MaterialIcon:  symbolIcon(noonCondition, false),
		Sunrise:       fmtClock(sunrise),
		Sunset:        fmtClock(sunset),
		UVIndex:       fmt.Sprintf("%.1f", uv),
		PressureHPa:   fmt.Sprintf("%.0f", pressureSum),
		CloudCover:    fmt.Sprintf("%.0f%%", cloudSum),
		WindGust:      fmt.Sprintf("%.0f %s", u.Speed(gust), u.SpeedSymbol),
		WindDirection: compass(windDirSum),
		ChanceOfRain:  chanceString(noonPop),
		Hourly:        hourly,
	}
}

func fetch(city string, fahrenheit bool) (*WeatherResult, error) {
	lat, lon, location, err := geocode(city)
	if err != nil {
		return nil, err
	}
	fr, err := fetchForecast(lat, lon)
	if err != nil {
		return nil, err
	}
	ts := fr.Properties.Timeseries
	u := unitsFor(fahrenheit)

	now := parseISO(ts[0].Time)
	todaySunrise, todaySunset, _ := fetchSun(lat, lon, now)

	dates, grouped := groupByDate(ts, forecastDays)

	forecast := make([]DailyForecast, 0, len(dates))
	for i, date := range dates {
		sunrise, sunset := todaySunrise, todaySunset
		if i > 0 {
			if s, e, serr := fetchSun(lat, lon, mustParseDate(date)); serr == nil {
				sunrise, sunset = s, e
			}
		}
		forecast = append(forecast, buildDailyForecast(date, grouped[date], sunrise, sunset, u))
	}

	curDetails := ts[0].Data.Instant.Details
	feels := feelsLikeC(curDetails.AirTemperature, curDetails.WindSpeed, curDetails.RelativeHumidity)
	curCondition := "unknown"
	if p := periodFor(ts[0].Data); p != nil {
		curCondition = p.Summary.SymbolCode
	}
	night := isNight(now, todaySunrise, todaySunset)

	return &WeatherResult{
		Location:         location,
		Date:             now.Format("2006-01-02"),
		Daytime:          !night,
		Sunrise:          fmtClock(todaySunrise),
		Sunset:           fmtClock(todaySunset),
		CurrentTemp:      degSym(u.Temp(curDetails.AirTemperature), u.TempSymbol),
		CurrentEmoji:     symbolEmoji(curCondition, night),
		MaterialIcon:     symbolIcon(curCondition, night),
		CurrentCondition: conditionLabel(curCondition),
		FeelsLike:        degSym(u.Temp(feels), u.TempSymbol),
		Humidity:         fmt.Sprintf("%.0f%%", curDetails.RelativeHumidity),
		DewPoint:         degSym(u.Temp(curDetails.DewPointTemperature), u.TempSymbol),
		WindSpeed:        fmt.Sprintf("%.0f %s", u.Speed(curDetails.WindSpeed), u.SpeedSymbol),
		WindDirection:    compass(curDetails.WindFromDirection),
		WindGust:         fmt.Sprintf("%.0f %s", u.Speed(curDetails.WindSpeedGust), u.SpeedSymbol),
		PressureHPa:      fmt.Sprintf("%.0f", curDetails.AirPressureAtSeaLevel),
		CloudCover:       fmt.Sprintf("%.0f%%", curDetails.CloudAreaFraction),
		FogAreaFraction:  fmt.Sprintf("%.0f%%", curDetails.FogAreaFraction),
		UVIndex:          fmt.Sprintf("%.1f", curDetails.UVIndexClearSky),
		Forecast:         forecast,
	}, nil
}

func errorTemplate(city, errMsg string) *WeatherResult {
	now := time.Now()
	forecast := make([]DailyForecast, 0, forecastDays)
	for i := 0; i < forecastDays; i++ {
		d := now.AddDate(0, 0, i)
		forecast = append(forecast, DailyForecast{
			Date:          dayLabel(d.Format("2006-01-02")),
			MaxTemp:       "—",
			MinTemp:       "—",
			AvgTemp:       "—",
			Condition:     "Unknown",
			Emoji:         "🌥️",
			MaterialIcon:  "cloud",
			Sunrise:       "—",
			Sunset:        "—",
			UVIndex:       "—",
			PressureHPa:   "—",
			CloudCover:    "—",
			WindGust:      "—",
			WindDirection: "—",
			ChanceOfRain:  "N/A",
			Hourly:        []HourlyEntry{},
		})
	}
	return &WeatherResult{
		Error:            errMsg,
		Location:         city,
		Date:             now.Format("2006-01-02"),
		Daytime:          now.Hour() >= 6 && now.Hour() < 20,
		Sunrise:          "—",
		Sunset:           "—",
		CurrentTemp:      "—",
		CurrentEmoji:     "🌥️",
		MaterialIcon:     "cloud",
		CurrentCondition: "Unknown",
		FeelsLike:        "—",
		Humidity:         "—",
		DewPoint:         "—",
		WindSpeed:        "—",
		WindDirection:    "—",
		WindGust:         "—",
		PressureHPa:      "—",
		CloudCover:       "—",
		FogAreaFraction:  "—",
		UVIndex:          "—",
		Forecast:         forecast,
	}
}

func printResult(w *WeatherResult) {
	out, _ := json.Marshal(w)
	fmt.Println(string(out))
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
	flag.Parse()
	c := *city
	if c == "" {
		c = *shortCity
	}
	if c == "" {
		c = flag.Arg(0)
	}
	if c == "" {
		printResult(errorTemplate("", "Usage: weather_service <city | --city <city>> [--fahrenheit]"))
		return
	}
	fh, err := acquireLock()
	if err != nil {
		printResult(errorTemplate(c, err.Error()))
		return
	}
	defer fh.Close()
	w, err := fetch(c, *fahrenheit || *shortFahrenheit)
	if err != nil {
		printResult(errorTemplate(c, err.Error()))
		return
	}
	printResult(w)
}
