.pragma library

// Loudie — biquad magnitude response.
//
// The universal currency for this whole plugin is the tuple
//   (type, frequency, gain, Q)
// because that is exactly what EasyEffects/LSP store per band, and exactly
// what AutoEQ / EqualizerAPO / REW / Wavelet import into. One shape, one
// code path: what we draw is what we send.
//
// Coefficients are the RBJ Audio EQ Cookbook forms, which is what LSP's
// para_equalizer uses for the modes Loudie exposes.

var FS = 48000;

// Index order MUST match EasyEffects' `bandTypeLabels`
// (src/contents/kcfg/easyeffects_db_equalizer_channel.kcfg), because the
// socket takes the integer index, not the name.
var TYPES = [
    "Off",           // 0
    "Bell",          // 1
    "Hi-pass",       // 2
    "Hi-shelf",      // 3
    "Lo-pass",       // 4
    "Lo-shelf",      // 5
    "Notch",         // 6
    "Resonance",     // 7
    "Allpass",       // 8
    "Bandpass",      // 9
    "Ladder-pass",   // 10
    "Ladder-rej"     // 11
];

function typeName(index) {
    return TYPES[index] || "Bell";
}

function typeIndex(name) {
    for (var i = 0; i < TYPES.length; i++)
        if (TYPES[i] === name)
            return i;
    return 1;
}

// {b0,b1,b2,a0,a1,a2}, or null when the band has no magnitude effect.
function coeffs(type, freq, gain, q, fs) {
    fs = fs || FS;
    var t = (typeof type === "number") ? type : typeIndex(type);

    if (t <= 0 || t === 8) // Off, Allpass -> flat magnitude
        return null;

    freq = Math.max(1, Math.min(freq, fs * 0.49));
    gain = gain || 0;
    q = Math.max(0.05, q || 0.707);

    var w0 = 2 * Math.PI * freq / fs;
    var cw = Math.cos(w0);
    var sw = Math.sin(w0);
    var A = Math.pow(10, gain / 40);
    var alpha = sw / (2 * q);
    var b0, b1, b2, a0, a1, a2;

    switch (t) {
    case 3: { // Hi-shelf
        var sa = 2 * Math.sqrt(A) * (sw / 2 * Math.SQRT2);
        b0 = A * ((A + 1) + (A - 1) * cw + sa);
        b1 = -2 * A * ((A - 1) + (A + 1) * cw);
        b2 = A * ((A + 1) + (A - 1) * cw - sa);
        a0 = (A + 1) - (A - 1) * cw + sa;
        a1 = 2 * ((A - 1) - (A + 1) * cw);
        a2 = (A + 1) - (A - 1) * cw - sa;
        break;
    }
    case 5: { // Lo-shelf
        var sb = 2 * Math.sqrt(A) * (sw / 2 * Math.SQRT2);
        b0 = A * ((A + 1) - (A - 1) * cw + sb);
        b1 = 2 * A * ((A - 1) - (A + 1) * cw);
        b2 = A * ((A + 1) - (A - 1) * cw - sb);
        a0 = (A + 1) + (A - 1) * cw + sb;
        a1 = -2 * ((A - 1) + (A + 1) * cw);
        a2 = (A + 1) + (A - 1) * cw - sb;
        break;
    }
    case 2: // Hi-pass
        b0 = (1 + cw) / 2; b1 = -(1 + cw); b2 = (1 + cw) / 2;
        a0 = 1 + alpha; a1 = -2 * cw; a2 = 1 - alpha;
        break;
    case 4: // Lo-pass
        b0 = (1 - cw) / 2; b1 = 1 - cw; b2 = (1 - cw) / 2;
        a0 = 1 + alpha; a1 = -2 * cw; a2 = 1 - alpha;
        break;
    case 6: // Notch
        b0 = 1; b1 = -2 * cw; b2 = 1;
        a0 = 1 + alpha; a1 = -2 * cw; a2 = 1 - alpha;
        break;
    case 9: // Bandpass (0 dB peak)
        b0 = alpha; b1 = 0; b2 = -alpha;
        a0 = 1 + alpha; a1 = -2 * cw; a2 = 1 - alpha;
        break;
    default: // 1 Bell, 7 Resonance, 10/11 Ladder — approximated as peaking
        b0 = 1 + alpha * A; b1 = -2 * cw; b2 = 1 - alpha * A;
        a0 = 1 + alpha / A; a1 = -2 * cw; a2 = 1 - alpha / A;
        break;
    }

    return { b0: b0, b1: b1, b2: b2, a0: a0, a1: a1, a2: a2 };
}

function bandDb(type, freq, gain, q, f, fs) {
    var c = coeffs(type, freq, gain, q, fs);
    if (!c)
        return 0;

    fs = fs || FS;
    var w = 2 * Math.PI * f / fs;
    var c1 = Math.cos(w), s1 = Math.sin(w);
    var c2 = Math.cos(2 * w), s2 = Math.sin(2 * w);

    var nr = c.b0 + c.b1 * c1 + c.b2 * c2;
    var ni = -(c.b1 * s1 + c.b2 * s2);
    var dr = c.a0 + c.a1 * c1 + c.a2 * c2;
    var di = -(c.a1 * s1 + c.a2 * s2);

    var num = nr * nr + ni * ni;
    var den = dr * dr + di * di;
    if (den <= 0)
        return 0;

    return 10 * Math.log10(num / den);
}

// Cascaded biquads multiply magnitude, so dB sum.
function totalDb(bands, f, fs) {
    var sum = 0;
    for (var i = 0; i < bands.length; i++) {
        var b = bands[i];
        if (!b || b.mute)
            continue;
        sum += bandDb(b.type, b.freq, b.gain, b.q, f, fs);
    }
    return sum;
}

// Sum of all active band gains — used to suggest automatic preamp headroom.
function peakBoost(bands) {
    var sum = 0;
    for (var i = 0; i < bands.length; i++) {
        var b = bands[i];
        if (!b || b.mute || b.type <= 0)
            continue;
        if (b.gain > 0)
            sum += b.gain;
    }
    return sum;
}

function freqToNorm(f) {
    var lo = Math.log10(20), hi = Math.log10(20000);
    return (Math.log10(Math.max(20, Math.min(20000, f))) - lo) / (hi - lo);
}

function normToFreq(n) {
    var lo = Math.log10(20), hi = Math.log10(20000);
    return Math.pow(10, lo + Math.max(0, Math.min(1, n)) * (hi - lo));
}
