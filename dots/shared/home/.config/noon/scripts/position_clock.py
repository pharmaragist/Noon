#!/usr/bin/env python3
"""Choose where the desktop clock sits on a depth-mask wallpaper.

Input is the foreground/depth mask (alpha) plus the wallpaper luminance.
Candidate rectangles use the clock's exact aspect ratio and are scored on
composition preferences:

  - near a rule-of-thirds line, so the clock reads as deliberate placement;
  - touching the subject silhouette, with a slight overlap so the foreground
    layer covers part of the clock for a depth-immersed look;
  - on quiet background, measured by luminance edges and variance;
  - inside a safety margin, never clipped by the screen edge;
  - larger when scores are close, so the clock stays readable.

Usage: position_clock.py IMAGE [ASPECT]
"""

import json
import sys

import numpy as np
from PIL import Image

WIDTH = 100
ALPHA_THRESHOLD = 8
MAX_SIZE = 0.75
MIN_SIZE = 0.15
MAX_OVERLAP = 0.20
MIN_OVERLAP = 0.02
MARGIN = 0.03
NEAR_RADIUS = 5
THIRDS_SIGMA = 0.20
TARGET_OVERLAP = 0.07
OVERLAP_SIGMA = 0.13
NEAR_FULL = 0.12
VARIANCE_FULL = 0.04
SIZE_TOLERANCE = 0.20

WEIGHT_THIRDS = 1.25
WEIGHT_CONTACT = 1.0
WEIGHT_OVERLAP = 0.45
WEIGHT_QUIET = 0.8
WEIGHT_AREA = 0.6


def integral(values):
    out = np.zeros((values.shape[0] + 1, values.shape[1] + 1), dtype=np.float64)
    out[1:, 1:] = values.cumsum(0).cumsum(1)
    return out


def window_sums(table, height, width):
    return (
        table[height:, width:]
        - table[:-height, width:]
        - table[height:, :-width]
        + table[:-height, :-width]
    )


def dilate(mask, radius):
    out = mask.copy()
    for _ in range(radius):
        grown = out.copy()
        grown[1:] |= out[:-1]
        grown[:-1] |= out[1:]
        grown[:, 1:] |= out[:, :-1]
        grown[:, :-1] |= out[:, 1:]
        out = grown
    return out


def load_grid(image_path):
    img = Image.open(image_path)
    if "A" not in img.getbands():
        sys.exit("image has no alpha channel")
    rows = max(1, round(img.height * WIDTH / img.width))
    alpha = img.getchannel("A").resize((WIDTH, rows), Image.BOX)
    gray = img.convert("L").resize((WIDTH, rows), Image.BOX)
    subject = (np.asarray(alpha) > ALPHA_THRESHOLD).astype(np.float64)
    return subject, np.asarray(gray, dtype=np.float64) / 255.0


def edge_map(gray):
    if gray.shape[0] < 2 or gray.shape[1] < 2:
        return np.zeros_like(gray)
    dy, dx = np.gradient(gray)
    magnitude = np.hypot(dy, dx)
    scale = np.percentile(magnitude, 90)
    return np.clip(magnitude / (scale + 1e-9), 0.0, 1.0)


def fit(image_path, aspect):
    subject, gray = load_grid(image_path)
    rows, cols = subject.shape
    has_subject = bool(subject.any())
    near = dilate(subject > 0, NEAR_RADIUS).astype(np.float64)

    sum_subject = integral(subject)
    sum_near = integral(near)
    sum_edge = integral(edge_map(gray))
    sum_gray = integral(gray)
    sum_gray2 = integral(gray * gray)

    margin = max(1, round(MARGIN * min(rows, cols)))
    max_area = (MAX_SIZE * rows) * (MAX_SIZE * cols)
    min_height = max(1, round(rows * MIN_SIZE))
    max_height = max(min_height, int(rows * MAX_SIZE))

    best = None
    per_size = []
    for height in range(max_height, min_height - 1, -1):
        width = max(1, round(height * aspect))
        if height > rows - 2 * margin or width > cols - 2 * margin:
            continue

        area = height * width
        overlap = window_sums(sum_subject, height, width) / area
        valid = overlap <= MAX_OVERLAP
        if has_subject:
            valid &= overlap >= MIN_OVERLAP

        top, left = np.broadcast_arrays(
            np.arange(rows - height + 1)[:, None],
            np.arange(cols - width + 1)[None, :],
        )
        valid &= (top >= margin) & (left >= margin)
        valid &= (top + height <= rows - margin) & (left + width <= cols - margin)
        if not valid.any():
            continue

        contact = np.clip(window_sums(sum_near, height, width) / area / NEAR_FULL, 0.0, 1.0)
        edges = window_sums(sum_edge, height, width) / area
        gray_sum = window_sums(sum_gray, height, width)
        gray_sq = window_sums(sum_gray2, height, width)
        variance = np.maximum(0.0, gray_sq / area - (gray_sum / area) ** 2)
        quiet = 1.0 - 0.6 * edges - 0.4 * np.clip(variance / VARIANCE_FULL, 0.0, 1.0)

        center_x = (left + width / 2) / cols
        center_y = (top + height / 2) / rows
        off_x = np.minimum(abs(center_x - 1 / 3), abs(center_x - 2 / 3))
        off_y = np.minimum(abs(center_y - 1 / 3), abs(center_y - 2 / 3))
        thirds = np.exp(-((off_x / THIRDS_SIGMA) ** 2) - ((off_y / THIRDS_SIGMA) ** 2))

        band = np.exp(-(((overlap - TARGET_OVERLAP) / OVERLAP_SIGMA) ** 2))
        size_bonus = area / max_area

        score = (
            WEIGHT_THIRDS * thirds
            + WEIGHT_CONTACT * contact
            + WEIGHT_OVERLAP * band
            + WEIGHT_QUIET * quiet
            + WEIGHT_AREA * size_bonus
        )
        score = np.where(valid, score, -np.inf)
        index = np.unravel_index(np.argmax(score), score.shape)
        value = float(score[index])
        if not np.isfinite(value):
            continue
        candidate = (
            value,
            int(left[index]),
            int(top[index]),
            width,
            height,
            float(overlap[index]),
            float(gray_sum[index] / area),
        )
        per_size.append(candidate)
        if best is None or value > best[0]:
            best = candidate

    if not per_size:
        return fallback(rows, cols, aspect, margin)

    # Scores are not perfectly comparable across sizes: a smaller rect can hit
    # the overlap band more precisely. Accept the largest rect whose score is
    # within tolerance of the global best, so the clock stays readable.
    threshold = best[0] - SIZE_TOLERANCE
    best = max((c for c in per_size if c[0] >= threshold), key=lambda c: (c[3] * c[4], c[0]))

    _, left, top, width, height, overlap, luminance = best
    return {
        "fitX": left / cols,
        "fitY": top / rows,
        "fitW": width / cols,
        "fitH": height / rows,
        "overlap": overlap,
        "luminance": luminance,
    }


def fallback(rows, cols, aspect, margin):
    height = max(1, round((rows - 2 * margin) * 0.6))
    width = max(1, min(round(height * aspect), cols - 2 * margin))
    height = min(height, rows - 2 * margin)
    left = round(cols * 2 / 3 - width / 2)
    top = round(rows / 3 - height / 2)
    left = min(max(left, margin), cols - margin - width)
    top = min(max(top, margin), rows - margin - height)
    return {
        "fitX": left / cols,
        "fitY": top / rows,
        "fitW": width / cols,
        "fitH": height / rows,
        "overlap": 0.0,
        "luminance": 0.0,
    }


def main():
    if len(sys.argv) not in (2, 3):
        sys.exit("usage: position_clock.py IMAGE [ASPECT]")
    aspect = float(sys.argv[2]) if len(sys.argv) == 3 else 1.0
    if aspect <= 0:
        sys.exit("aspect must be positive")
    result = fit(sys.argv[1], aspect)
    print(json.dumps({key: round(value, 4) for key, value in result.items()}))


if __name__ == "__main__":
    main()
