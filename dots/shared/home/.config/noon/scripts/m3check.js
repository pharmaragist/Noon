#!/usr/bin/env node



const assert = require("assert");
const fs = require("fs");
const path = require("path");

function loadJs(file) {
    const src = fs.readFileSync(file, "utf8").replace(/^\.pragma.*$/m, "");
    const mod = { exports: {} };
    const fn = new Function("module", "exports", "require", "__filename", "__dirname", src);
    fn(mod, mod.exports, require, file, path.dirname(file));
    return mod.exports;
}

const m3 = loadJs(path.join(__dirname, "..", "vendors", "colors", "M3.js"));
const { build } = loadJs(path.join(__dirname, "..", "vendors", "colors", "M3Palette.js"));

const dark = build("#6750a4", true, m3);
const light = build("0xff6750a4", false, m3);


const qmlColor = { r: 0x67 / 255, g: 0x50 / 255, b: 0xa4 / 255, a: 1, valid: true };
assert.strictEqual(build(qmlColor, true, m3).colPrimary, dark.colPrimary, "QML color object == hex string");

assert.strictEqual(dark.colPrimary, "#ffcfbcff", "dark primary tone 80");
assert.strictEqual(dark.colOnPrimary, "#ff381e72", "dark onPrimary tone 20");
assert.strictEqual(dark.colPrimaryContainer, "#ff4f378a", "dark primaryContainer tone 30");
assert.strictEqual(dark.colOnPrimaryContainer, "#ffe9ddff", "dark onPrimaryContainer tone 90");
assert.strictEqual(dark.colLayer0, "#ff141316", "dark background tone 6");
assert.strictEqual(dark.colOnLayer0, "#ffe6e1e6", "dark onBackground tone 90");
assert.strictEqual(dark.colOutlineVariant, "#ff49454e", "dark outlineVariant tone 30");
assert.strictEqual(dark.colError, "#ffffb4ab", "dark error tone 80");

assert.strictEqual(light.colPrimary, "#ff6750a4", "light primary tone 40");
assert.strictEqual(light.colOnPrimary, "#ffffffff", "light onPrimary tone 100");

assert.ok(dark.colPrimary !== dark.colOnPrimary, "primary and onPrimary differ");
assert.ok(parseInt(dark.colOnSurfaceDisabled.slice(1, 3), 16) < 0xff, "disabled role has alpha");
assert.ok(dark.colSuccess !== dark.colError, "success is its own palette");
assert.ok(dark.colLayer0 !== dark.colLayer4, "layers are distinct");

const expected = [
    "colBackground", "colOnBackground", "colSubtext", "colTint",
    "colLayer0", "colOnLayer0", "colLayer0Hover", "colLayer0Active", "colLayer0Border",
    "colLayer1", "colOnLayer1", "colOnLayer1Inactive", "colLayer1Hover", "colLayer1Active",
    "colLayer2", "colOnLayer2", "colOnLayer2Disabled", "colLayer2Hover", "colLayer2Active", "colLayer2Disabled",
    "colLayer3", "colOnLayer3", "colLayer3Hover", "colLayer3Active",
    "colLayer4", "colOnLayer4", "colLayer4Hover", "colLayer4Active",
    "colPrimary", "colOnPrimary", "colPrimaryHover", "colPrimaryActive",
    "colPrimaryContainer", "colOnPrimaryContainer", "colPrimaryContainerHover", "colPrimaryContainerActive",
    "colSecondary", "colOnSecondary", "colSecondaryHover", "colSecondaryActive",
    "colSecondaryContainer", "colOnSecondaryContainer", "colSecondaryContainerHover", "colSecondaryContainerActive",
    "colTertiary", "colOnTertiary", "colTertiaryHover", "colTertiaryActive",
    "colTertiaryContainer", "colOnTertiaryContainer", "colTertiaryContainerHover", "colTertiaryContainerActive",
    "colOnSurface", "colOnSurfaceVariant", "colOnSurfaceDisabled", "colOnSurfaceLowEmphasis",
    "colInverseSurface", "colInverseOnSurface",
    "colSurfaceContainerLow", "colSurfaceContainer", "colSurfaceContainerHigh", "colSurfaceContainerHighest",
    "colSurfaceContainerHighestHover", "colSurfaceContainerHighestActive",
    "colSuccess", "colOnSuccess", "colSuccessContainer", "colOnSuccessContainer",
    "colError", "colOnError", "colErrorHover", "colErrorActive",
    "colErrorContainer", "colOnErrorContainer", "colErrorContainerHover", "colErrorContainerActive",
    "colOutline", "colOutlineVariant", "colTooltip", "colOnTooltip", "colScrim", "colShadow",
];

for (const key of expected)
    assert.ok(key in dark, `dark missing ${key}`);
for (const key of expected)
    assert.ok(key in light, `light missing ${key}`);

console.log("m3check: OK (" + expected.length + " roles verified dark+light)");
