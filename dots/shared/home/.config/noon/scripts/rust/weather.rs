use anyhow::{bail, Context, Result};
use chrono::{DateTime, Days, Local, NaiveDate, Timelike};
use clap::Parser;
use fd_lock::RwLock;
use serde::{de::DeserializeOwned, Deserialize};
use serde_json::{json, Value};
use std::{fs::File, time::Duration};

const FORECAST_URL: &str = "https://api.met.no/weatherapi/locationforecast/2.0/complete";
const SUN_URL: &str = "https://api.met.no/weatherapi/sunrise/3.0/sun";
const GEOCODE_URL: &str = "https://geocoding-api.open-meteo.com/v1/search";
const USER_AGENT: &str = "weather_service/1.0 (contact: cdumb@proton.me)";
const LOCK_PATH: &str = "/tmp/weather_service.lock";
const FORECAST_DAYS: usize = 3;

#[derive(Deserialize, Default)]
#[serde(default)]
struct Hit {
    name: String,
    admin1: String,
    country: String,
    latitude: f64,
    longitude: f64,
}

#[derive(Deserialize, Default)]
#[serde(default)]
struct Details {
    air_pressure_at_sea_level: f64,
    air_temperature: f64,
    cloud_area_fraction: f64,
    dew_point_temperature: f64,
    fog_area_fraction: f64,
    relative_humidity: f64,
    ultraviolet_index_clear_sky: f64,
    wind_from_direction: f64,
    wind_speed: f64,
    wind_speed_of_gust: f64,
}

#[derive(Deserialize, Default)]
#[serde(default)]
struct Period {
    summary: Summary,
    details: PeriodDetails,
}

#[derive(Deserialize, Default)]
#[serde(default)]
struct Summary {
    symbol_code: String,
}

#[derive(Deserialize, Default)]
#[serde(default)]
struct PeriodDetails {
    precipitation_amount: f64,
    probability_of_precipitation: Option<f64>,
}

#[derive(Deserialize)]
struct Step {
    time: DateTime<Local>,
    data: StepData,
}

#[derive(Deserialize)]
struct StepData {
    instant: Instant,
    next_1_hours: Option<Period>,
    next_6_hours: Option<Period>,
    next_12_hours: Option<Period>,
}

#[derive(Deserialize)]
struct Instant {
    details: Details,
}

impl Step {
    fn details(&self) -> &Details {
        &self.data.instant.details
    }

    fn period(&self) -> Option<&Period> {
        let d = &self.data;
        d.next_1_hours.as_ref().or(d.next_6_hours.as_ref()).or(d.next_12_hours.as_ref())
    }

    fn code(&self) -> &str {
        self.period().map_or("", |p| p.summary.symbol_code.as_str())
    }
}

type Sun = Option<(DateTime<Local>, DateTime<Local>)>;

#[derive(Clone, Copy)]
struct Units(bool);

impl Units {
    fn temp(self, c: f64) -> String {
        if self.0 {
            format!("{:.0}°F", c * 1.8 + 32.0)
        } else {
            format!("{c:.0}°C")
        }
    }

    fn speed(self, ms: f64) -> f64 {
        ms * if self.0 { 2.23694 } else { 3.6 }
    }

    fn wind(self, ms: f64) -> String {
        format!("{:.0} {}", self.speed(ms), if self.0 { "mph" } else { "km/h" })
    }
}

const VISUALS: [(&str, &str, &str, &str, &str); 10] = [
    ("thunder", "thunderstorm", "thunderstorm", "⛈️", "⛈️"),
    ("snow", "ac_unit", "ac_unit", "❄️", "❄️"),
    ("sleet", "weather_mix", "weather_mix", "🌧️", "🌧️"),
    ("fog", "foggy", "foggy", "🌫️", "🌫️"),
    ("rain", "rainy", "rainy", "🌧️", "🌧️"),
    ("showers", "rainy", "rainy", "🌦️", "🌦️"),
    ("partlycloudy", "partly_cloudy_day", "cloudy", "⛅", "☁️"),
    ("clearsky", "partly_cloudy_day", "clear_night", "☀️", "🌙"),
    ("fair", "partly_cloudy_day", "clear_night", "⛅", "🌙"),
    ("cloudy", "cloud", "cloud", "☁️", "☁️"),
];

fn symbol(code: &str, night: bool) -> (&'static str, &'static str) {
    VISUALS
        .iter()
        .find(|v| code.contains(v.0))
        .map_or(("cloudy", "🌥️"), |v| if night { (v.2, v.4) } else { (v.1, v.3) })
}

fn label(code: &str) -> String {
    let mut text = code.split('_').next().unwrap_or_default().to_string();
    for word in ["partlycloudy", "clearsky"] {
        text = text.replace(word, &format!(" {} ", word.replace("cloudy", " cloudy").replace("sky", " sky")));
    }
    for word in ["cloudy", "fair", "fog", "heavy", "light", "showers", "thunder", "rain", "snow", "sleet", "and"] {
        text = text.replace(word, &format!(" {word} "));
    }
    let text = text.split_whitespace().collect::<Vec<_>>().join(" ");
    let mut chars = text.chars();
    chars.next().map_or("Unknown".into(), |c| c.to_uppercase().chain(chars).collect())
}

fn compass(deg: f64) -> &'static str {
    const DIRS: [&str; 16] = [
        "N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE", "S", "SSW", "SW", "WSW", "W", "WNW",
        "NW", "NNW",
    ];
    DIRS[(deg / 22.5 + 0.5) as usize % 16]
}

fn feels_like(c: f64, wind_ms: f64, humidity: f64) -> f64 {
    if c <= 10.0 && wind_ms > 1.34 {
        let kmh = wind_ms * 3.6;
        13.12 + 0.6215 * c - 11.37 * kmh.powf(0.16) + 0.3965 * c * kmh.powf(0.16)
    } else if c >= 27.0 && humidity >= 40.0 {
        -8.784 + 1.611 * c + 2.339 * humidity - 0.146 * c * humidity
    } else {
        c
    }
}

fn is_night(t: DateTime<Local>, sun: Sun) -> bool {
    match sun {
        Some((rise, set)) => t < rise || t > set,
        None => !(6..20).contains(&t.hour()),
    }
}

fn clock(t: Option<DateTime<Local>>) -> String {
    t.map_or("—".into(), |t| t.format("%H:%M").to_string())
}

fn pct(p: Option<f64>) -> String {
    p.map_or("N/A".into(), |p| format!("{p:.0}%"))
}

fn day_label(date: NaiveDate) -> String {
    let today = Local::now().date_naive();
    if date == today {
        "Today".into()
    } else if date == today + Days::new(1) {
        "Tomorrow".into()
    } else {
        date.format("%a").to_string()
    }
}

fn get<T: DeserializeOwned>(agent: &ureq::Agent, url: &str, query: &[(&str, &str)]) -> Result<T> {
    let mut req = agent.get(url);
    for (k, v) in query {
        req = req.query(k, v);
    }
    Ok(req.call()?.into_json()?)
}

fn fetch_sun(agent: &ureq::Agent, lat: &str, lon: &str, date: NaiveDate) -> Sun {
    #[derive(Deserialize)]
    struct Time {
        time: Option<DateTime<Local>>,
    }
    #[derive(Deserialize)]
    struct Props {
        sunrise: Option<Time>,
        sunset: Option<Time>,
    }
    #[derive(Deserialize)]
    struct Resp {
        properties: Props,
    }
    let date = date.to_string();
    let offset = Local::now().format("%:z").to_string();
    let resp: Resp = get(
        agent,
        SUN_URL,
        &[("lat", lat), ("lon", lon), ("date", &date), ("offset", &offset)],
    )
    .ok()?;
    Some((resp.properties.sunrise?.time?, resp.properties.sunset?.time?))
}

fn column<'a>(steps: &'a [Step], f: fn(&Details) -> f64) -> impl Iterator<Item = f64> + 'a {
    steps.iter().map(move |s| f(s.details()))
}

fn mean(steps: &[Step], f: fn(&Details) -> f64) -> f64 {
    column(steps, f).sum::<f64>() / steps.len() as f64
}

fn max(steps: &[Step], f: fn(&Details) -> f64) -> f64 {
    column(steps, f).fold(f64::MIN, f64::max)
}

fn build_day(steps: &[Step], sun: Sun, u: Units) -> Value {
    let hi = max(steps, |d| d.air_temperature);
    let lo = -max(steps, |d| -d.air_temperature);
    let noon = steps
        .iter()
        .min_by_key(|s| (s.time.num_seconds_from_midnight() as i64 - 43_200).abs())
        .expect("chunks are never empty");
    let (icon, emoji) = symbol(noon.code(), false);

    let hourly: Vec<Value> = steps
        .iter()
        .map(|s| {
            let d = s.details();
            let p = s.period();
            let (icon, emoji) = symbol(s.code(), is_night(s.time, sun));
            json!({
                "time": s.time.format("%H:%M").to_string(),
                "temp": u.temp(d.air_temperature),
                "condition": label(s.code()),
                "emoji": emoji,
                "material_icon": icon,
                "wind_speed": format!("{:.0}", u.speed(d.wind_speed)),
                "wind_direction": compass(d.wind_from_direction),
                "precipitation_mm": format!("{:.1}", p.map_or(0.0, |p| p.details.precipitation_amount)),
                "chance_of_rain": pct(p.and_then(|p| p.details.probability_of_precipitation)),
            })
        })
        .collect();

    json!({
        "date": day_label(steps[0].time.date_naive()),
        "max_temp": u.temp(hi),
        "min_temp": u.temp(lo),
        "avg_temp": u.temp((hi + lo) / 2.0),
        "condition": label(noon.code()),
        "emoji": emoji,
        "material_icon": icon,
        "sunrise": clock(sun.map(|s| s.0)),
        "sunset": clock(sun.map(|s| s.1)),
        "uv_index": format!("{:.1}", max(steps, |d| d.ultraviolet_index_clear_sky)),
        "pressure_hpa": format!("{:.0}", mean(steps, |d| d.air_pressure_at_sea_level)),
        "cloud_cover": format!("{:.0}%", mean(steps, |d| d.cloud_area_fraction)),
        "wind_gust": u.wind(max(steps, |d| d.wind_speed_of_gust)),
        "wind_direction": compass(mean(steps, |d| d.wind_from_direction)),
        "chance_of_rain": pct(noon.period().and_then(|p| p.details.probability_of_precipitation)),
        "hourly": hourly,
    })
}

fn fetch(city: &str, u: Units) -> Result<Value> {
    #[derive(Deserialize)]
    struct Geo {
        #[serde(default)]
        results: Vec<Hit>,
    }
    #[derive(Deserialize)]
    struct Forecast {
        properties: Props,
    }
    #[derive(Deserialize)]
    struct Props {
        timeseries: Vec<Step>,
    }

    let agent = ureq::AgentBuilder::new()
        .timeout(Duration::from_secs(15))
        .user_agent(USER_AGENT)
        .build();

    let geo: Geo = get(&agent, GEOCODE_URL, &[("name", city), ("count", "1"), ("format", "json")])
        .context("geocode")?;
    let hit = geo
        .results
        .into_iter()
        .next()
        .with_context(|| format!("no location found for {city:?}"))?;
    let location = [&hit.name, &hit.admin1, &hit.country]
        .into_iter()
        .filter(|s| !s.is_empty())
        .map(String::as_str)
        .collect::<Vec<_>>()
        .join(", ");
    let (lat, lon) = (format!("{:.4}", hit.latitude), format!("{:.4}", hit.longitude));

    let forecast: Forecast = get(&agent, FORECAST_URL, &[("lat", &lat), ("lon", &lon)])
        .context("forecast")?;
    let series = forecast.properties.timeseries;
    let first = series.first().context("empty forecast response")?;

    let days: Vec<&[Step]> = series
        .chunk_by(|a, b| a.time.date_naive() == b.time.date_naive())
        .take(FORECAST_DAYS)
        .collect();
    let suns: Vec<Sun> = days
        .iter()
        .map(|d| fetch_sun(&agent, &lat, &lon, d[0].time.date_naive()))
        .collect();
    let forecast: Vec<Value> = days
        .iter()
        .zip(&suns)
        .map(|(steps, sun)| build_day(steps, *sun, u))
        .collect();

    let d = first.details();
    let night = is_night(first.time, suns[0]);
    let (icon, emoji) = symbol(first.code(), night);

    Ok(json!({
        "location": location,
        "date": first.time.format("%Y-%m-%d").to_string(),
        "daytime": !night,
        "sunrise": clock(suns[0].map(|s| s.0)),
        "sunset": clock(suns[0].map(|s| s.1)),
        "current_temp": u.temp(d.air_temperature),
        "current_emoji": emoji,
        "material_icon": icon,
        "current_condition": label(first.code()),
        "feels_like": u.temp(feels_like(d.air_temperature, d.wind_speed, d.relative_humidity)),
        "humidity": format!("{:.0}%", d.relative_humidity),
        "dew_point": u.temp(d.dew_point_temperature),
        "wind_speed": u.wind(d.wind_speed),
        "wind_direction": compass(d.wind_from_direction),
        "wind_gust": u.wind(d.wind_speed_of_gust),
        "pressure_hpa": format!("{:.0}", d.air_pressure_at_sea_level),
        "cloud_cover": format!("{:.0}%", d.cloud_area_fraction),
        "fog_area_fraction": format!("{:.0}%", d.fog_area_fraction),
        "uv_index": format!("{:.1}", d.ultraviolet_index_clear_sky),
        "forecast": forecast,
    }))
}

fn failure(city: &str, error: String) -> Value {
    let now = Local::now();
    let forecast: Vec<Value> = (0..FORECAST_DAYS as u64)
        .map(|i| {
            let mut day = json!({
                "date": day_label((now + Days::new(i)).date_naive()),
                "condition": "Unknown",
                "emoji": "🌥️",
                "material_icon": "cloud",
                "chance_of_rain": "N/A",
                "hourly": [],
            });
            for key in [
                "max_temp", "min_temp", "avg_temp", "sunrise", "sunset", "uv_index",
                "pressure_hpa", "cloud_cover", "wind_gust", "wind_direction",
            ] {
                day[key] = "—".into();
            }
            day
        })
        .collect();
    let mut out = json!({
        "error": error,
        "location": city,
        "date": now.format("%Y-%m-%d").to_string(),
        "daytime": (6..20).contains(&now.hour()),
        "current_emoji": "🌥️",
        "material_icon": "cloud",
        "current_condition": "Unknown",
        "forecast": forecast,
    });
    for key in [
        "sunrise", "sunset", "current_temp", "feels_like", "humidity", "dew_point", "wind_speed",
        "wind_direction", "wind_gust", "pressure_hpa", "cloud_cover", "fog_area_fraction",
        "uv_index",
    ] {
        out[key] = "—".into();
    }
    out
}

#[derive(Parser)]
struct Args {
    #[arg(short, long)]
    city: Option<String>,
    #[arg(conflicts_with = "city")]
    name: Option<String>,
    #[arg(short, long)]
    fahrenheit: bool,
}

fn run(city: &str, u: Units) -> Result<Value> {
    if city.is_empty() {
        bail!("Usage: weather_service <city | --city <city>> [--fahrenheit]");
    }
    let file = File::options().create(true).write(true).truncate(false).open(LOCK_PATH)?;
    let mut lock = RwLock::new(file);
    let _guard = lock.write()?;
    fetch(city, u)
}

fn main() {
    let args = Args::parse();
    let city = args.city.or(args.name).unwrap_or_default();
    let output = run(&city, Units(args.fahrenheit)).unwrap_or_else(|e| failure(&city, format!("{e:#}")));
    println!("{output}");
}
