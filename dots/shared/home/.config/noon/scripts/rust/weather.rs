//! Weather JSON for QML, sourced from MET Norway and Open-Meteo.

use std::fs::File;
use std::time::Duration;

use anyhow::{bail, Context, Result};
use chrono::{DateTime, Days, Local, NaiveDate, Timelike};
use clap::Parser;
use fd_lock::RwLock;
use rayon::prelude::*;
use serde::{de::DeserializeOwned, Deserialize, Serialize};

const FORECAST_URL: &str = "https://api.met.no/weatherapi/locationforecast/2.0/complete";
const SUN_URL: &str = "https://api.met.no/weatherapi/sunrise/3.0/sun";
const GEOCODE_URL: &str = "https://geocoding-api.open-meteo.com/v1/search";
const USER_AGENT: &str = "weather_service/1.0 (contact: cdumb@proton.me)";
const DAYS: usize = 3;
const DASH: &str = "—";

#[derive(Parser)]
#[command(about = "Print weather JSON for a city")]
struct Args {
    #[arg(short, long)]
    city: Option<String>,
    #[arg(conflicts_with = "city")]
    name: Option<String>,
    #[arg(short, long)]
    fahrenheit: bool,
}

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
        format!(
            "{:.0} {}",
            self.speed(ms),
            if self.0 { "mph" } else { "km/h" }
        )
    }
}

#[derive(Serialize)]
struct Hourly {
    time: String,
    temp: String,
    condition: String,
    emoji: &'static str,
    material_icon: &'static str,
    wind_speed: String,
    wind_direction: &'static str,
    precipitation_mm: String,
    chance_of_rain: String,
}

#[derive(Serialize)]
struct Day {
    date: String,
    max_temp: String,
    min_temp: String,
    avg_temp: String,
    condition: String,
    emoji: &'static str,
    material_icon: &'static str,
    sunrise: String,
    sunset: String,
    uv_index: String,
    pressure_hpa: String,
    cloud_cover: String,
    wind_gust: String,
    wind_direction: &'static str,
    chance_of_rain: String,
    hourly: Vec<Hourly>,
}

impl Day {
    fn unknown(date: String) -> Self {
        Self {
            date,
            max_temp: DASH.into(),
            min_temp: DASH.into(),
            avg_temp: DASH.into(),
            condition: "Unknown".into(),
            emoji: "🌥️",
            material_icon: "cloud",
            sunrise: DASH.into(),
            sunset: DASH.into(),
            uv_index: DASH.into(),
            pressure_hpa: DASH.into(),
            cloud_cover: DASH.into(),
            wind_gust: DASH.into(),
            wind_direction: DASH,
            chance_of_rain: "N/A".into(),
            hourly: Vec::new(),
        }
    }
}

#[derive(Serialize)]
struct Weather {
    location: String,
    date: String,
    daytime: bool,
    sunrise: String,
    sunset: String,
    current_temp: String,
    current_emoji: &'static str,
    material_icon: &'static str,
    current_condition: String,
    feels_like: String,
    humidity: String,
    dew_point: String,
    wind_speed: String,
    wind_direction: &'static str,
    wind_gust: String,
    pressure_hpa: String,
    cloud_cover: String,
    fog_area_fraction: String,
    uv_index: String,
    forecast: Vec<Day>,
}

impl Weather {
    fn unknown(city: &str) -> Self {
        let now = Local::now();
        Self {
            location: city.into(),
            date: now.format("%Y-%m-%d").to_string(),
            daytime: (6..20).contains(&now.hour()),
            sunrise: DASH.into(),
            sunset: DASH.into(),
            current_temp: DASH.into(),
            current_emoji: "🌥️",
            material_icon: "cloud",
            current_condition: "Unknown".into(),
            feels_like: DASH.into(),
            humidity: DASH.into(),
            dew_point: DASH.into(),
            wind_speed: DASH.into(),
            wind_direction: DASH,
            wind_gust: DASH.into(),
            pressure_hpa: DASH.into(),
            cloud_cover: DASH.into(),
            fog_area_fraction: DASH.into(),
            uv_index: DASH.into(),
            forecast: (0..DAYS as u64)
                .map(|i| Day::unknown(day_label((now + Days::new(i)).date_naive())))
                .collect(),
        }
    }
}

#[derive(Serialize)]
struct Failure {
    error: String,
    #[serde(flatten)]
    weather: Weather,
}

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
        self.data
            .next_1_hours
            .as_ref()
            .or(self.data.next_6_hours.as_ref())
            .or(self.data.next_12_hours.as_ref())
    }

    fn code(&self) -> &str {
        self.period().map_or("", |p| &p.summary.symbol_code)
    }
}

type Sun = Option<(DateTime<Local>, DateTime<Local>)>;

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
        .map_or(("cloudy", "🌥️"), |v| {
            if night {
                (v.2, v.4)
            } else {
                (v.1, v.3)
            }
        })
}

fn label(code: &str) -> String {
    let root = code.split('_').next().unwrap_or("");
    let spaced = ["partlycloudy", "clearsky"]
        .iter()
        .fold(root.to_string(), |text, word| {
            text.replace(
                word,
                if *word == "partlycloudy" {
                    "partly cloudy"
                } else {
                    "clear sky"
                },
            )
        });
    let spaced = [
        "cloudy", "fair", "fog", "heavy", "light", "showers", "thunder", "rain", "snow", "sleet",
        "and",
    ]
    .iter()
    .fold(spaced, |text, word| {
        text.replace(word, &format!(" {word} "))
    });

    let text = spaced.split_whitespace().collect::<Vec<_>>().join(" ");
    let mut chars = text.chars();
    chars.next().map_or("Unknown".into(), |first| {
        first.to_uppercase().chain(chars).collect()
    })
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
    t.map_or_else(|| DASH.into(), |t| t.format("%H:%M").to_string())
}

fn pct(value: Option<f64>) -> String {
    value.map_or_else(|| "N/A".into(), |v| format!("{v:.0}%"))
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
    let mut request = agent.get(url);
    for (key, value) in query {
        request = request.query(key, value);
    }
    let mut response = request.call()?;
    Ok(response.body_mut().read_json()?)
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
    let response: Resp = get(
        agent,
        SUN_URL,
        &[
            ("lat", lat),
            ("lon", lon),
            ("date", &date),
            ("offset", &offset),
        ],
    )
    .ok()?;
    Some((
        response.properties.sunrise?.time?,
        response.properties.sunset?.time?,
    ))
}

fn mean(steps: &[Step], field: fn(&Details) -> f64) -> f64 {
    steps.iter().map(|s| field(s.details())).sum::<f64>() / steps.len() as f64
}

fn peak(steps: &[Step], field: fn(&Details) -> f64) -> f64 {
    steps
        .iter()
        .map(|s| field(s.details()))
        .fold(f64::MIN, f64::max)
}

fn build_day(steps: &[Step], sun: Sun, units: Units) -> Day {
    let high = peak(steps, |d| d.air_temperature);
    let low = -peak(steps, |d| -d.air_temperature);
    let noon = steps
        .iter()
        .min_by_key(|s| (s.time.num_seconds_from_midnight() as i64 - 43_200).abs())
        .expect("day chunks are never empty");
    let (icon, emoji) = symbol(noon.code(), false);

    let hourly = steps
        .iter()
        .map(|step| {
            let details = step.details();
            let period = step.period();
            let (icon, emoji) = symbol(step.code(), is_night(step.time, sun));
            Hourly {
                time: step.time.format("%H:%M").to_string(),
                temp: units.temp(details.air_temperature),
                condition: label(step.code()),
                emoji,
                material_icon: icon,
                wind_speed: format!("{:.0}", units.speed(details.wind_speed)),
                wind_direction: compass(details.wind_from_direction),
                precipitation_mm: format!(
                    "{:.1}",
                    period.map_or(0.0, |p| p.details.precipitation_amount)
                ),
                chance_of_rain: pct(period.and_then(|p| p.details.probability_of_precipitation)),
            }
        })
        .collect();

    Day {
        date: day_label(steps[0].time.date_naive()),
        max_temp: units.temp(high),
        min_temp: units.temp(low),
        avg_temp: units.temp((high + low) / 2.0),
        condition: label(noon.code()),
        emoji,
        material_icon: icon,
        sunrise: clock(sun.map(|s| s.0)),
        sunset: clock(sun.map(|s| s.1)),
        uv_index: format!("{:.1}", peak(steps, |d| d.ultraviolet_index_clear_sky)),
        pressure_hpa: format!("{:.0}", mean(steps, |d| d.air_pressure_at_sea_level)),
        cloud_cover: format!("{:.0}%", mean(steps, |d| d.cloud_area_fraction)),
        wind_gust: units.wind(peak(steps, |d| d.wind_speed_of_gust)),
        wind_direction: compass(mean(steps, |d| d.wind_from_direction)),
        chance_of_rain: pct(noon
            .period()
            .and_then(|p| p.details.probability_of_precipitation)),
        hourly,
    }
}

fn fetch(city: &str, units: Units) -> Result<Weather> {
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

    let agent: ureq::Agent = ureq::Agent::config_builder()
        .timeout_global(Some(Duration::from_secs(15)))
        .user_agent(USER_AGENT)
        .build()
        .into();

    let geo: Geo = get(
        &agent,
        GEOCODE_URL,
        &[("name", city), ("count", "1"), ("format", "json")],
    )
    .context("geocoding")?;
    let hit = geo
        .results
        .into_iter()
        .next()
        .with_context(|| format!("no location found for {city:?}"))?;
    let location = [hit.name, hit.admin1, hit.country]
        .into_iter()
        .filter(|s| !s.is_empty())
        .collect::<Vec<_>>()
        .join(", ");
    let (lat, lon) = (
        format!("{:.4}", hit.latitude),
        format!("{:.4}", hit.longitude),
    );

    let forecast: Forecast =
        get(&agent, FORECAST_URL, &[("lat", &lat), ("lon", &lon)]).context("forecast")?;
    let series = forecast.properties.timeseries;
    let first = series.first().context("empty forecast response")?;

    let days: Vec<&[Step]> = series
        .chunk_by(|a, b| a.time.date_naive() == b.time.date_naive())
        .take(DAYS)
        .collect();
    let suns: Vec<Sun> = days
        .par_iter()
        .map(|steps| fetch_sun(&agent, &lat, &lon, steps[0].time.date_naive()))
        .collect();

    Ok(Weather {
        date: first.time.format("%Y-%m-%d").to_string(),
        daytime: !is_night(first.time, suns[0]),
        sunrise: clock(suns[0].map(|s| s.0)),
        sunset: clock(suns[0].map(|s| s.1)),
        forecast: days
            .iter()
            .zip(&suns)
            .map(|(steps, sun)| build_day(steps, *sun, units))
            .collect(),
        location,
        current_temp: units.temp(first.details().air_temperature),
        current_emoji: symbol(first.code(), is_night(first.time, suns[0])).1,
        material_icon: symbol(first.code(), is_night(first.time, suns[0])).0,
        current_condition: label(first.code()),
        feels_like: units.temp(feels_like(
            first.details().air_temperature,
            first.details().wind_speed,
            first.details().relative_humidity,
        )),
        humidity: format!("{:.0}%", first.details().relative_humidity),
        dew_point: units.temp(first.details().dew_point_temperature),
        wind_speed: units.wind(first.details().wind_speed),
        wind_direction: compass(first.details().wind_from_direction),
        wind_gust: units.wind(first.details().wind_speed_of_gust),
        pressure_hpa: format!("{:.0}", first.details().air_pressure_at_sea_level),
        cloud_cover: format!("{:.0}%", first.details().cloud_area_fraction),
        fog_area_fraction: format!("{:.0}%", first.details().fog_area_fraction),
        uv_index: format!("{:.1}", first.details().ultraviolet_index_clear_sky),
    })
}

fn run(city: &str, units: Units) -> Result<Weather> {
    if city.is_empty() {
        bail!("usage: weather <city | --city <city>> [--fahrenheit]");
    }
    let file = File::options()
        .create(true)
        .write(true)
        .truncate(false)
        .open(std::env::temp_dir().join("weather_service.lock"))?;
    let mut lock = RwLock::new(file);
    let _guard = lock.write()?;
    fetch(city, units)
}

fn main() -> Result<()> {
    let args = Args::parse();
    let city = args.city.or(args.name).unwrap_or_default();
    let output = match run(&city, Units(args.fahrenheit)) {
        Ok(weather) => serde_json::to_string(&weather)?,
        Err(error) => serde_json::to_string(&Failure {
            error: format!("{error:#}"),
            weather: Weather::unknown(&city),
        })?,
    };
    println!("{output}");
    Ok(())
}
