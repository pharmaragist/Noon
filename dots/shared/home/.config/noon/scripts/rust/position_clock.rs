//! Find a clock placement on a depth-mask wallpaper; prints JSON.

use std::path::{Path, PathBuf};

use anyhow::{bail, Context, Result};
use clap::Parser;
use image::imageops::FilterType;
use image::GenericImageView;
use rayon::prelude::*;
use serde::Serialize;

const GRID_WIDTH: u32 = 100;
const ALPHA_CUTOFF: u8 = 8;
const MAX_SIZE: f64 = 0.75;
const MIN_SIZE: f64 = 0.15;
const MAX_OVERLAP: f64 = 0.20;
const MIN_OVERLAP: f64 = 0.02;
const MARGIN: f64 = 0.03;
const NEAR_RADIUS: usize = 5;
const THIRDS_SIGMA: f64 = 0.20;
const TARGET_OVERLAP: f64 = 0.07;
const OVERLAP_SIGMA: f64 = 0.13;
const NEAR_FULL: f64 = 0.12;
const VARIANCE_FULL: f64 = 0.04;
const SIZE_TOLERANCE: f64 = 0.20;

const W_THIRDS: f64 = 1.25;
const W_CONTACT: f64 = 1.0;
const W_OVERLAP: f64 = 0.45;
const W_QUIET: f64 = 0.8;
const W_AREA: f64 = 0.6;

#[derive(Parser)]
#[command(about = "Find the best clock placement on a depth-mask wallpaper")]
struct Args {
    image: PathBuf,
    #[arg(default_value_t = 1.0)]
    aspect: f64,
}

#[derive(Serialize)]
struct Fit {
    #[serde(rename = "fitX")]
    x: f64,
    #[serde(rename = "fitY")]
    y: f64,
    #[serde(rename = "fitW")]
    w: f64,
    #[serde(rename = "fitH")]
    h: f64,
    overlap: f64,
    luminance: f64,
}

#[derive(Clone)]
struct Grid {
    rows: usize,
    cols: usize,
    data: Vec<f64>,
}

impl Grid {
    fn new(rows: usize, cols: usize, data: Vec<f64>) -> Self {
        Self { rows, cols, data }
    }

    fn zeros(rows: usize, cols: usize) -> Self {
        Self::new(rows, cols, vec![0.0; rows * cols])
    }

    fn at(&self, row: usize, col: usize) -> f64 {
        self.data[row * self.cols + col]
    }

    fn set(&mut self, row: usize, col: usize, value: f64) {
        self.data[row * self.cols + col] = value;
    }

    fn integral(&self) -> Grid {
        let (rows, cols) = (self.rows, self.cols);
        let mut table = Grid::zeros(rows + 1, cols + 1);
        for r in 0..rows {
            let mut prefix = 0.0;
            for c in 0..cols {
                prefix += self.at(r, c);
                let above = table.at(r, c + 1);
                table.set(r + 1, c + 1, above + prefix);
            }
        }
        table
    }

    fn window(&self, top: usize, left: usize, height: usize, width: usize) -> f64 {
        let (bottom, right) = (top + height, left + width);
        self.at(bottom, right) - self.at(top, right) - self.at(bottom, left) + self.at(top, left)
    }

    fn dilate(&self, radius: usize) -> Grid {
        let mut out = self.clone();
        for _ in 0..radius {
            let mut grown = out.clone();
            for r in 0..out.rows {
                for c in 0..out.cols {
                    let cell = out.at(r, c) > 0.0;
                    let near = (r > 0 && out.at(r - 1, c) > 0.0)
                        || (r + 1 < out.rows && out.at(r + 1, c) > 0.0)
                        || (c > 0 && out.at(r, c - 1) > 0.0)
                        || (c + 1 < out.cols && out.at(r, c + 1) > 0.0);
                    if !cell && near {
                        grown.set(r, c, 1.0);
                    }
                }
            }
            out = grown;
        }
        out
    }
}

fn grid_from_channel(bytes: &[u8], rows: usize, cols: usize, scale: f64) -> Grid {
    Grid::new(
        rows,
        cols,
        bytes.iter().map(|&v| f64::from(v) * scale).collect(),
    )
}

fn gradient(values: &[f64], i: usize) -> f64 {
    let n = values.len();
    match i {
        0 if n > 2 => (-3.0 * values[0] + 4.0 * values[1] - values[2]) / 2.0,
        0 => values[1] - values[0],
        i if i + 1 == n && n > 2 => {
            (3.0 * values[n - 1] - 4.0 * values[n - 2] + values[n - 3]) / 2.0
        }
        i if i + 1 == n => values[n - 1] - values[n - 2],
        i => (values[i + 1] - values[i - 1]) / 2.0,
    }
}

fn edges(gray: &Grid) -> Grid {
    let mut out = Grid::zeros(gray.rows, gray.cols);
    if gray.rows < 2 || gray.cols < 2 {
        return out;
    }
    let columns: Vec<Vec<f64>> = (0..gray.cols)
        .map(|c| (0..gray.rows).map(|r| gray.at(r, c)).collect())
        .collect();
    let row_gradients: Vec<Vec<f64>> = (0..gray.rows)
        .map(|r| {
            let row = &gray.data[r * gray.cols..(r + 1) * gray.cols];
            (0..gray.cols).map(|c| gradient(row, c)).collect()
        })
        .collect();
    let col_gradients: Vec<Vec<f64>> = columns
        .iter()
        .map(|column| (0..gray.rows).map(|r| gradient(column, r)).collect())
        .collect();
    for r in 0..gray.rows {
        for c in 0..gray.cols {
            out.set(r, c, col_gradients[c][r].hypot(row_gradients[r][c]));
        }
    }
    let scale = percentile(&out.data, 0.90);
    for value in &mut out.data {
        *value = (*value / (scale + 1e-9)).clamp(0.0, 1.0);
    }
    out
}

fn percentile(data: &[f64], fraction: f64) -> f64 {
    let mut sorted = data.to_vec();
    sorted.sort_by(f64::total_cmp);
    let pos = fraction * (sorted.len() - 1) as f64;
    let lo = pos.floor() as usize;
    let hi = pos.ceil() as usize;
    sorted[lo] + (pos - lo as f64) * (sorted[hi] - sorted[lo])
}

#[derive(Clone, Copy)]
struct Candidate {
    score: f64,
    left: usize,
    top: usize,
    width: usize,
    height: usize,
    overlap: f64,
    luminance: f64,
}

fn round4(value: f64) -> f64 {
    (value * 10_000.0).round() / 10_000.0
}

fn fallback(rows: usize, cols: usize, aspect: f64, margin: usize) -> Fit {
    let available_r = (rows - 2 * margin) as f64;
    let available_c = (cols - 2 * margin) as f64;
    let height = ((available_r * 0.6).round() as usize).max(1) as f64;
    let width = (height * aspect).round().min(available_c).max(1.0);
    let height = height.min(available_r);
    let left = ((cols as f64 * 2.0 / 3.0 - width / 2.0).round() as isize).clamp(
        margin as isize,
        cols as isize - margin as isize - width as isize,
    );
    let top = ((rows as f64 / 3.0 - height / 2.0).round() as isize).clamp(
        margin as isize,
        rows as isize - margin as isize - height as isize,
    );
    Fit {
        x: round4(left as f64 / cols as f64),
        y: round4(top as f64 / rows as f64),
        w: round4(width / cols as f64),
        h: round4(height / rows as f64),
        overlap: 0.0,
        luminance: 0.0,
    }
}

fn best_for_height(
    height: usize,
    aspect: f64,
    grid: &Grid,
    tables: &Tables,
    bounds: &Bounds,
) -> Option<Candidate> {
    let width = ((height as f64 * aspect).round() as usize).max(1);
    if width > bounds.max_width || height > bounds.max_height {
        return None;
    }
    let area = (height * width) as f64;
    let mut best: Option<Candidate> = None;

    for top in bounds.margin..=bounds.max_top(height) {
        for left in bounds.margin..=bounds.max_left(width) {
            let overlap = tables.subject.window(top, left, height, width) / area;
            if overlap > MAX_OVERLAP || (bounds.has_subject && overlap < MIN_OVERLAP) {
                continue;
            }
            let contact =
                (tables.near.window(top, left, height, width) / area / NEAR_FULL).clamp(0.0, 1.0);
            let edges = tables.edges.window(top, left, height, width) / area;
            let sum = tables.gray.window(top, left, height, width);
            let sum_sq = tables.gray_sq.window(top, left, height, width);
            let variance = (sum_sq / area - (sum / area).powi(2)).max(0.0);
            let quiet = 1.0 - 0.6 * edges - 0.4 * (variance / VARIANCE_FULL).clamp(0.0, 1.0);

            let cx = (left as f64 + width as f64 / 2.0) / grid.cols as f64;
            let cy = (top as f64 + height as f64 / 2.0) / grid.rows as f64;
            let off_x = (cx - 1.0 / 3.0).abs().min((cx - 2.0 / 3.0).abs());
            let off_y = (cy - 1.0 / 3.0).abs().min((cy - 2.0 / 3.0).abs());
            let thirds = (-(off_x / THIRDS_SIGMA).powi(2) - (off_y / THIRDS_SIGMA).powi(2)).exp();
            let band = (-(((overlap - TARGET_OVERLAP) / OVERLAP_SIGMA).powi(2))).exp();
            let score = W_THIRDS * thirds
                + W_CONTACT * contact
                + W_OVERLAP * band
                + W_QUIET * quiet
                + W_AREA * (area / bounds.max_area);

            if best.is_none_or(|b: Candidate| score > b.score) {
                best = Some(Candidate {
                    score,
                    left,
                    top,
                    width,
                    height,
                    overlap,
                    luminance: sum / area,
                });
            }
        }
    }
    best
}

struct Tables {
    subject: Grid,
    near: Grid,
    edges: Grid,
    gray: Grid,
    gray_sq: Grid,
}

struct Bounds {
    margin: usize,
    max_width: usize,
    max_height: usize,
    max_area: f64,
    has_subject: bool,
    rows: usize,
    cols: usize,
}

impl Bounds {
    fn max_top(&self, height: usize) -> usize {
        self.rows - height - self.margin
    }
    fn max_left(&self, width: usize) -> usize {
        self.cols - width - self.margin
    }
}

fn fit(path: &Path, aspect: f64) -> Result<Fit> {
    let img = image::open(path).with_context(|| format!("opening {}", path.display()))?;
    if !img.color().has_alpha() {
        bail!("image has no alpha channel");
    }
    let (w, h) = img.dimensions();
    let rows = ((h as f64 * f64::from(GRID_WIDTH) / w as f64).round() as usize).max(1);
    let small = img.resize_exact(GRID_WIDTH, rows as u32, FilterType::Triangle);
    let rgba = small.to_rgba8();
    let luma = small.to_luma8();

    let subject = Grid::new(
        rows,
        GRID_WIDTH as usize,
        rgba.chunks_exact(4)
            .map(|p| f64::from(p[3] > ALPHA_CUTOFF))
            .collect(),
    );
    let gray = grid_from_channel(luma.as_raw(), rows, GRID_WIDTH as usize, 1.0 / 255.0);

    let margin = (MARGIN * rows.min(GRID_WIDTH as usize) as f64)
        .round()
        .max(1.0) as usize;
    let bounds = Bounds {
        margin,
        max_width: (GRID_WIDTH as usize).saturating_sub(2 * margin),
        max_height: rows.saturating_sub(2 * margin),
        max_area: (MAX_SIZE * rows as f64) * (MAX_SIZE * f64::from(GRID_WIDTH)),
        has_subject: subject.data.iter().any(|&v| v > 0.0),
        rows,
        cols: GRID_WIDTH as usize,
    };
    let tables = Tables {
        subject: subject.integral(),
        near: subject.dilate(NEAR_RADIUS).integral(),
        edges: edges(&gray).integral(),
        gray: gray.clone().integral(),
        gray_sq: Grid::new(
            gray.rows,
            gray.cols,
            gray.data.iter().map(|v| v * v).collect(),
        )
        .integral(),
    };

    if rows <= 2 * margin || GRID_WIDTH as usize <= 2 * margin {
        return Ok(fallback(rows, GRID_WIDTH as usize, aspect, margin));
    }
    let min_height = ((rows as f64 * MIN_SIZE).round() as usize).max(1);
    let max_height = min_height.max((rows as f64 * MAX_SIZE) as usize);

    let candidates: Vec<Candidate> = (min_height..=max_height)
        .into_par_iter()
        .filter_map(|h| best_for_height(h, aspect, &gray, &tables, &bounds))
        .collect();
    let Some(best_any) = candidates.iter().max_by(|a, b| a.score.total_cmp(&b.score)) else {
        return Ok(fallback(rows, GRID_WIDTH as usize, aspect, margin));
    };
    let threshold = best_any.score - SIZE_TOLERANCE;
    let chosen = candidates
        .iter()
        .filter(|c| c.score >= threshold)
        .max_by(|a, b| {
            (a.width * a.height)
                .cmp(&(b.width * b.height))
                .then_with(|| a.score.total_cmp(&b.score))
        })
        .expect("candidates is non-empty");

    Ok(Fit {
        x: round4(chosen.left as f64 / bounds.cols as f64),
        y: round4(chosen.top as f64 / bounds.rows as f64),
        w: round4(chosen.width as f64 / bounds.cols as f64),
        h: round4(chosen.height as f64 / bounds.rows as f64),
        overlap: round4(chosen.overlap),
        luminance: round4(chosen.luminance),
    })
}

fn main() -> Result<()> {
    let args = Args::parse();
    if args.aspect <= 0.0 {
        bail!("aspect must be positive");
    }
    println!(
        "{}",
        serde_json::to_string(&fit(&args.image, args.aspect)?)?
    );
    Ok(())
}
