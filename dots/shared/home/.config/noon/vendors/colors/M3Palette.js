








function parseColor(value) {
    if (typeof value === "number")
        return value >>> 0;
    if (typeof value === "object" && value !== null && value.valid === true) {
        const to255 = (v) => Math.round(Math.max(0, Math.min(1, v)) * 255);
        const a = value.a !== undefined ? value.a : 1;
        return (Math.round(a * 255) << 24) | (to255(value.r) << 16) | (to255(value.g) << 8) | to255(value.b);
    }
    if (typeof value !== "string")
        return 0xffffffff;
    let s = value.trim();
    if (s[0] === "#")
        s = s.slice(1);
    if (s.length === 3)
        s = s[0] + s[0] + s[1] + s[1] + s[2] + s[2];
    if (s.length === 6)
        s = "ff" + s;
    const v = parseInt(s, 16);
    return isNaN(v) ? 0xffffffff : v;
}

function argbToCss(v) {
    const hx = (x) => (x < 16 ? "0" : "") + x.toString(16);
    return "#" + hx((v >>> 24) & 0xff) + hx((v >>> 16) & 0xff) + hx((v >>> 8) & 0xff) + hx(v & 0xff);
}

function mix(a, b, t) {
    const ar = (a >>> 16) & 0xff, ag = (a >>> 8) & 0xff, ab = a & 0xff;
    const br = (b >>> 16) & 0xff, bg = (b >>> 8) & 0xff, bb = b & 0xff;
    const r = Math.round(ar * t + br * (1 - t));
    const g = Math.round(ag * t + bg * (1 - t));
    const bl = Math.round(ab * t + bb * (1 - t));
    return (0xff << 24) | (r << 16) | (g << 8) | bl;
}

function transparentize(c, amount) {
    const a = Math.round(((c >>> 24) & 0xff) * (1 - amount));
    return (a << 24) | (c & 0x00ffffff);
}



const sanitizeDegreesDouble = (degrees) => {
    degrees = degrees % 360.0;
    return degrees < 0 ? degrees + 360.0 : degrees;
};

const sanitizeDegreesInt = (degrees) => {
    degrees = degrees % 360;
    return degrees < 0 ? degrees + 360 : degrees;
};

function labFromArgb(argb) {
    const linearized = (v) => {
        const n = v / 255.0;
        return n <= 0.040449936 ? n / 12.92 * 100.0 : Math.pow((n + 0.055) / 1.055, 2.4) * 100.0;
    };
    const r = linearized((argb >> 16) & 0xff);
    const g = linearized((argb >> 8) & 0xff);
    const b = linearized(argb & 0xff);
    const x = (0.41233895 * r + 0.35762064 * g + 0.18051042 * b) / 95.047;
    const y = (0.2126 * r + 0.7152 * g + 0.0722 * b) / 100.0;
    const z = (0.01932141 * r + 0.11916382 * g + 0.95034478 * b) / 108.883;
    const labF = (t) => (t > 216.0 / 24389.0 ? Math.pow(t, 1.0 / 3.0) : (24389.0 / 27.0 * t + 16) / 116);
    const fx = labF(x), fy = labF(y), fz = labF(z);
    return [116.0 * fy - 16, 500.0 * (fx - fy), 200.0 * (fy - fz)];
}



class TemperatureCache {
    constructor(input, Hct) {
        this.input = input;
        this.Hct = Hct;
        this.hctsByHueCache = [];
        this.hctsByTempCache = [];
        this.tempsByHctCache = new Map();
        this.complementCache = null;
        this.inputRelativeTemperatureCache = -1.0;
    }
    get hctsByHue() {
        if (this.hctsByHueCache.length > 0)
            return this.hctsByHueCache;
        const hcts = [];
        for (let hue = 0.0; hue <= 360.0; hue += 1.0)
            hcts.push(this.Hct.from(hue, this.input.chroma, this.input.tone));
        this.hctsByHueCache = hcts;
        return hcts;
    }
    get tempsByHct() {
        if (this.tempsByHctCache.size > 0)
            return this.tempsByHctCache;
        const all = this.hctsByHue.concat([this.input]);
        for (const h of all)
            this.tempsByHctCache.set(h, TemperatureCache.rawTemperature(h));
        return this.tempsByHctCache;
    }
    get hctsByTemp() {
        if (this.hctsByTempCache.length > 0)
            return this.hctsByTempCache;
        const temps = this.tempsByHct;
        const hcts = this.hctsByHue.concat([this.input]).sort((a, b) => temps.get(a) - temps.get(b));
        this.hctsByTempCache = hcts;
        return hcts;
    }
    get warmest() { return this.hctsByTemp[this.hctsByTemp.length - 1]; }
    get coldest() { return this.hctsByTemp[0]; }
    get inputRelativeTemperature() {
        if (this.inputRelativeTemperatureCache < 0.0)
            this.inputRelativeTemperatureCache = this.relativeTemperature(this.input);
        return this.inputRelativeTemperatureCache;
    }
    relativeTemperature(hct) {
        const range = this.tempsByHct.get(this.warmest) - this.tempsByHct.get(this.coldest);
        if (range === 0.0)
            return 0.5;
        return (this.tempsByHct.get(hct) - this.tempsByHct.get(this.coldest)) / range;
    }
    get complement() {
        if (this.complementCache != null)
            return this.complementCache;
        const coldest = this.coldest, warmest = this.warmest;
        const coldestTemp = this.tempsByHct.get(coldest), warmestTemp = this.tempsByHct.get(warmest);
        const range = warmestTemp - coldestTemp;
        const startHueIsColdestToWarmest = TemperatureCache.isBetween(this.input.hue, coldest.hue, warmest.hue);
        const startHue = startHueIsColdestToWarmest ? warmest.hue : coldest.hue;
        const endHue = startHueIsColdestToWarmest ? coldest.hue : warmest.hue;
        const complementRelativeTemp = 1.0 - this.inputRelativeTemperature;
        let smallestError = 1000.0;
        let answer = this.hctsByHue[Math.round(this.input.hue)];
        for (let hueAddend = 0.0; hueAddend <= 360.0; hueAddend += 1.0) {
            const hue = sanitizeDegreesDouble(startHue + hueAddend);
            if (!TemperatureCache.isBetween(hue, startHue, endHue))
                continue;
            const relativeTemp = (this.tempsByHct.get(this.hctsByHue[Math.round(hue)]) - coldestTemp) / range;
            const error = Math.abs(complementRelativeTemp - relativeTemp);
            if (error < smallestError) {
                smallestError = error;
                answer = this.hctsByHue[Math.round(hue)];
            }
        }
        this.complementCache = answer;
        return answer;
    }
    analogous(count = 5, divisions = 12) {
        const startHue = Math.round(this.input.hue);
        const startHct = this.hctsByHue[startHue];
        let lastTemp = this.relativeTemperature(startHct);
        const allColors = [startHct];
        let absoluteTotalTempDelta = 0.0;
        for (let i = 0; i < 360; i++) {
            const hct = this.hctsByHue[sanitizeDegreesInt(startHue + i)];
            const temp = this.relativeTemperature(hct);
            absoluteTotalTempDelta += Math.abs(temp - lastTemp);
            lastTemp = temp;
        }
        const tempStep = absoluteTotalTempDelta / divisions;
        let hueAddend = 1;
        let totalTempDelta = 0.0;
        lastTemp = this.relativeTemperature(startHct);
        while (allColors.length < divisions) {
            const hct = this.hctsByHue[sanitizeDegreesInt(startHue + hueAddend)];
            const temp = this.relativeTemperature(hct);
            totalTempDelta += Math.abs(temp - lastTemp);
            let indexSatisfied = totalTempDelta >= allColors.length * tempStep;
            let indexAddend = 1;
            while (indexSatisfied && allColors.length < divisions) {
                allColors.push(hct);
                indexSatisfied = totalTempDelta >= (allColors.length + indexAddend) * tempStep;
                indexAddend++;
            }
            lastTemp = temp;
            hueAddend++;
            if (hueAddend > 360) {
                while (allColors.length < divisions)
                    allColors.push(hct);
                break;
            }
        }
        const answers = [this.input];
        const increaseHueCount = Math.floor((count - 1) / 2.0);
        for (let i = 1; i < increaseHueCount + 1; i++)
            answers.splice(0, 0, allColors[(allColors.length - i) % allColors.length]);
        const decreaseHueCount = count - increaseHueCount - 1;
        for (let i = 1; i < decreaseHueCount + 1; i++)
            answers.push(allColors[i % allColors.length]);
        return answers;
    }
    static isBetween(angle, a, b) {
        if (a < b)
            return a <= angle && angle <= b;
        return a <= angle || angle <= b;
    }
    static rawTemperature(color) {
        const lab = labFromArgb(color.toInt());
        const hue = sanitizeDegreesDouble(Math.atan2(lab[2], lab[1]) * 180.0 / Math.PI);
        const chroma = Math.sqrt(lab[1] * lab[1] + lab[2] * lab[2]);
        return -0.5 + 0.02 * Math.pow(chroma, 1.07) * Math.cos(sanitizeDegreesDouble(hue - 50.0) * Math.PI / 180.0);
    }
}

function fixIfDisliked(hct, Hct) {
    const passes = Math.round(hct.hue) >= 90.0 && Math.round(hct.hue) <= 111.0 &&
        Math.round(hct.chroma) > 16.0 && Math.round(hct.tone) < 65.0;
    return passes ? Hct.from(hct.hue, hct.chroma, 70.0) : hct;
}

const VIBRANT_HUES = [0, 41, 61, 101, 131, 181, 251, 301, 360];
const VIBRANT_SECONDARY_ROTATIONS = [18, 15, 10, 12, 15, 18, 15, 12, 12];
const VIBRANT_TERTIARY_ROTATIONS = [35, 30, 20, 25, 30, 35, 30, 25, 25];
const EXPRESSIVE_HUES = [0, 21, 51, 121, 151, 191, 271, 321, 360];
const EXPRESSIVE_SECONDARY_ROTATIONS = [45, 95, 45, 20, 45, 90, 45, 45, 45];
const EXPRESSIVE_TERTIARY_ROTATIONS = [120, 120, 20, 45, 20, 15, 20, 120, 120];

function getRotatedHue(sourceColor, hues, rotations) {
    const sourceHue = sourceColor.hue;
    if (rotations.length === 1)
        return sanitizeDegreesDouble(sourceHue + rotations[0]);
    for (let i = 0; i < hues.length - 1; i++)
        if (hues[i] < sourceHue && sourceHue < hues[i + 1])
            return sanitizeDegreesDouble(sourceHue + rotations[i]);
    return sourceHue;
}

function variantPalettes(hct, m3, scheme) {
    const T = (hue, chroma) => m3.TonalPalette.fromHueAndChroma(hue, chroma);
    const h = hct.hue, c = hct.chroma;
    switch (scheme) {
        case "scheme-neutral":
            return { a1: T(h, 12), a2: T(h, 8), a3: T(h, 16), n1: T(h, 2), n2: T(h, 2) };
        case "scheme-expressive":
            return {
                a1: T(sanitizeDegreesDouble(h + 240), 40),
                a2: T(getRotatedHue(hct, EXPRESSIVE_HUES, EXPRESSIVE_SECONDARY_ROTATIONS), 24),
                a3: T(getRotatedHue(hct, EXPRESSIVE_HUES, EXPRESSIVE_TERTIARY_ROTATIONS), 32),
                n1: T(sanitizeDegreesDouble(h + 15), 8),
                n2: T(sanitizeDegreesDouble(h + 15), 12),
            };
        case "scheme-fidelity": {
            const cache = new TemperatureCache(hct, m3.Hct);
            return {
                a1: T(h, c),
                a2: T(h, Math.max(c - 32, c * 0.5)),
                a3: m3.TonalPalette.fromInt(fixIfDisliked(cache.complement, m3.Hct).toInt()),
                n1: T(h, c / 8),
                n2: T(h, c / 8 + 4),
            };
        }
        case "scheme-content": {
            const cache = new TemperatureCache(hct, m3.Hct);
            return {
                a1: T(h, c),
                a2: T(h, Math.max(c - 32, c * 0.5)),
                a3: m3.TonalPalette.fromInt(fixIfDisliked(cache.analogous(3, 6)[2], m3.Hct).toInt()),
                n1: T(h, c / 8),
                n2: T(h, c / 8 + 4),
            };
        }
        case "scheme-monochrome":
            return { a1: T(h, 0), a2: T(h, 0), a3: T(h, 0), n1: T(h, 0), n2: T(h, 0) };
        case "scheme-rainbow":
            return { a1: T(h, 48), a2: T(h, 16), a3: T(sanitizeDegreesDouble(h + 60), 24), n1: T(h, 0), n2: T(h, 0) };
        case "scheme-fruit-salad":
            return {
                a1: T(sanitizeDegreesDouble(h - 50), 48),
                a2: T(sanitizeDegreesDouble(h - 50), 36),
                a3: T(h, 36),
                n1: T(h, 10),
                n2: T(h, 16),
            };
        case "scheme-vibrant":
            return {
                a1: T(h, 200),
                a2: T(getRotatedHue(hct, VIBRANT_HUES, VIBRANT_SECONDARY_ROTATIONS), 24),
                a3: T(getRotatedHue(hct, VIBRANT_HUES, VIBRANT_TERTIARY_ROTATIONS), 32),
                n1: T(h, 10),
                n2: T(h, 12),
            };
        case "scheme-tonal-spot":
        default: 
            return { a1: T(h, 36), a2: T(h, 16), a3: T(sanitizeDegreesDouble(h + 60), 24), n1: T(h, 6), n2: T(h, 8) };
    }
}

function build(keyColor, dark, m3, scheme) {
    const hct = m3.Hct.fromInt(parseColor(keyColor));
    const p = variantPalettes(hct, m3, scheme || "scheme-tonal-spot");
    const a1 = p.a1, a2 = p.a2, a3 = p.a3, n = p.n1, nv = p.n2;
    const e = m3.TonalPalette.fromHueAndChroma(25, 84);
    const success = m3.TonalPalette.fromHueAndChroma(145, 50);

    const t = (palette, tone) => argbToCss(palette.tone(tone));
    const A = (argb) => argbToCss(argb);

    
    const primary = dark ? { color: 80, on: 20, container: 30, onContainer: 90 }
                         : { color: 40, on: 100, container: 90, onContainer: 10 };
    const error = primary;
    const successTones = primary;
    const fixed = { fixed: 90, fixedDim: 80 };
    const neutral = dark ? { bg: 6, on: 90, dim: 6, bright: 24, lowest: 4, low: 10, mid: 12, high: 17, highest: 22, inv: 90, onInv: 20 }
                         : { bg: 98, on: 10, dim: 87, bright: 98, lowest: 100, low: 96, mid: 94, high: 92, highest: 90, inv: 20, onInv: 95 };
    const neutralVariant = dark ? { surfaceVariant: 30, onSurfaceVariant: 80, outline: 60, outlineVariant: 30 }
                                : { surfaceVariant: 90, onSurfaceVariant: 30, outline: 50, outlineVariant: 80 };

    const onSurface = t(n, neutral.on);
    const background = t(n, neutral.bg);

    return {
        colBackground: background,
        colOnBackground: onSurface,
        colSubtext: t(nv, neutralVariant.outline),

        colLayer0: background,
        colOnLayer0: onSurface,
        colLayer0Hover: t(n, neutral.dim),
        colLayer0Active: t(n, neutral.low),
        colLayer0Border: t(nv, neutralVariant.outlineVariant),

        colLayer1: t(n, neutral.low),
        colOnLayer1: t(nv, neutralVariant.onSurfaceVariant),
        colOnLayer1Inactive: t(nv, neutralVariant.onSurfaceVariant),
        colLayer1Hover: t(n, neutral.mid),
        colLayer1Active: t(n, neutral.high),

        colLayer2: t(n, neutral.mid),
        colOnLayer2: onSurface,
        colOnLayer2Disabled: A(mix(n.tone(neutral.on), n.tone(neutral.bg), 0.4)),
        colLayer2Hover: t(n, neutral.high),
        colLayer2Active: t(n, neutral.highest),
        colLayer2Disabled: A(mix(n.tone(neutral.mid), n.tone(neutral.bg), 0.8)),

        colLayer3: t(n, neutral.high),
        colOnLayer3: onSurface,
        colLayer3Hover: t(n, neutral.highest),
        colLayer3Active: t(n, neutral.bright),

        colLayer4: t(n, neutral.highest),
        colOnLayer4: onSurface,
        colLayer4Hover: t(n, neutral.bright),
        colLayer4Active: t(n, neutral.bright),

        colPrimary: t(a1, primary.color),
        colOnPrimary: t(a1, primary.on),
        colPrimaryHover: t(a1, fixed.fixed),
        colPrimaryActive: t(a1, fixed.fixedDim),
        colPrimaryContainer: t(a1, primary.container),
        colOnPrimaryContainer: t(a1, primary.onContainer),
        colPrimaryContainerHover: t(a1, fixed.fixed),
        colPrimaryContainerActive: t(a1, fixed.fixedDim),

        colSecondary: t(a2, primary.color),
        colOnSecondary: t(a2, primary.on),
        colSecondaryHover: t(a2, fixed.fixed),
        colSecondaryActive: t(a2, fixed.fixedDim),
        colSecondaryContainer: t(a2, primary.container),
        colOnSecondaryContainer: t(a2, primary.onContainer),
        colSecondaryContainerHover: t(a2, fixed.fixed),
        colSecondaryContainerActive: t(a2, fixed.fixedDim),

        colTertiary: t(a3, primary.color),
        colOnTertiary: t(a3, primary.on),
        colTertiaryHover: t(a3, fixed.fixed),
        colTertiaryActive: t(a3, fixed.fixedDim),
        colTertiaryContainer: t(a3, primary.container),
        colOnTertiaryContainer: t(a3, primary.onContainer),
        colTertiaryContainerHover: t(a3, fixed.fixed),
        colTertiaryContainerActive: t(a3, fixed.fixedDim),

        colOnSurface: onSurface,
        colOnSurfaceVariant: t(nv, neutralVariant.onSurfaceVariant),
        colOnSurfaceDisabled: A(transparentize(n.tone(neutral.on), 0.4)),
        colOnSurfaceLowEmphasis: A(transparentize(n.tone(neutral.on), 0.6)),
        colInverseSurface: t(n, neutral.inv),
        colInverseOnSurface: t(n, neutral.onInv),

        colSurfaceContainerLow: t(n, neutral.low),
        colSurfaceContainer: t(n, neutral.mid),
        colSurfaceContainerHigh: t(n, neutral.high),
        colSurfaceContainerHighest: t(n, neutral.highest),
        colSurfaceContainerHighestHover: t(n, neutral.bright),
        colSurfaceContainerHighestActive: t(n, neutral.bright),

        colSuccess: t(success, successTones.color),
        colOnSuccess: t(success, successTones.on),
        colSuccessContainer: t(success, successTones.container),
        colOnSuccessContainer: t(success, successTones.onContainer),

        colError: t(e, error.color),
        colOnError: t(e, error.on),
        colErrorHover: t(e, error.container),
        colErrorActive: t(e, error.container),
        colErrorContainer: t(e, error.container),
        colOnErrorContainer: t(e, error.onContainer),
        colErrorContainerHover: t(e, error.color),
        colErrorContainerActive: t(e, error.color),

        colOutline: t(n, neutral.highest),
        colOutlineVariant: t(nv, neutralVariant.outlineVariant),
        colTooltip: background,
        colOnTooltip: onSurface,
        colScrim: A(transparentize(n.tone(0), 0.4)),
        colShadow: t(n, 0),
        colTint: A(transparentize(a2.tone(primary.container), 0.25)),
    };
}

if (typeof module !== "undefined" && module.exports)
    module.exports = { build: build };
