//! In-process video frame decoding via FFmpeg.

use std::path::Path;

use anyhow::{bail, Context, Result};
use ffmpeg_the_third::{
    codec,
    format::{self, Pixel},
    media::Type,
    software::scaling::{flag::Flags, Context as Scaler},
    util::frame::Video,
};
use image::RgbImage;

#[allow(dead_code)]
pub fn duration(path: &Path) -> Result<f64> {
    let input = format::input(path).with_context(|| format!("opening {}", path.display()))?;
    let micros = input.duration();
    if micros <= 0 {
        bail!("unknown duration for {}", path.display());
    }
    Ok(micros as f64 / 1_000_000.0)
}

pub fn frame_at(path: &Path, seconds: f64) -> Result<RgbImage> {
    let mut input = format::input(path).with_context(|| format!("opening {}", path.display()))?;
    let (mut decoder, time_base) = {
        let stream = input
            .streams()
            .best(Type::Video)
            .with_context(|| format!("no video stream in {}", path.display()))?;
        let params = stream.parameters();
        let codec = codec::decoder::find(params.id()).context("no matching decoder")?;
        let decoder = codec::Context::from_parameters(params)?
            .decoder()
            .open_as(codec)?
            .video()?;
        (decoder, stream.time_base())
    };

    let target = seconds.max(0.0);
    if target > 0.0 {
        let _ = input.seek((target * 1_000_000.0) as i64, ..);
    }

    for result in input.packets() {
        let (_, packet) = result?;
        let _ = decoder.send_packet(&packet);
        loop {
            let mut frame = Video::empty();
            if decoder.receive_frame(&mut frame).is_err() {
                break;
            }
            let reached = frame.pts().is_none_or(|pts| {
                target == 0.0
                    || pts as f64 * f64::from(time_base.numerator())
                        / f64::from(time_base.denominator())
                        + 1e-3
                        >= target
            });
            if reached {
                return scale(&frame);
            }
        }
    }

    let _ = decoder.send_eof();
    loop {
        let mut frame = Video::empty();
        if decoder.receive_frame(&mut frame).is_err() {
            break;
        }
        return scale(&frame);
    }

    bail!("no decodable frame in {}", path.display())
}

fn scale(frame: &Video) -> Result<RgbImage> {
    let (width, height) = (frame.width(), frame.height());
    let mut rgb = Video::new(Pixel::RGB24, width, height);
    Scaler::get(
        frame.format(),
        width,
        height,
        Pixel::RGB24,
        width,
        height,
        Flags::AREA,
    )?
    .run(frame, &mut rgb)?;

    let stride = rgb.stride(0);
    let data = rgb.data(0);
    let row = width as usize * 3;
    let mut image = RgbImage::new(width, height);
    for (y, target) in image.as_mut().chunks_exact_mut(row).enumerate() {
        target.copy_from_slice(&data[y * stride..y * stride + row]);
    }
    Ok(image)
}
