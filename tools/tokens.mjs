#!/usr/bin/env node
// Checks tokens/{light,dark}.json and tokens/themes/*.json, then writes them into the prototype and the clients in apps/.
// Nothing is written unless every check passes. Rules: docs/02-design-language.md#扩展接口
// Usage: node tools/tokens.mjs [prototype.html]
import { mkdirSync, readdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';

const root = new URL('..', import.meta.url);
const readJSON = path => JSON.parse(readFileSync(new URL(path, root), 'utf8'));
const flat = group => Object.fromEntries(Object.entries(group ?? {}).filter(([k]) => !k.startsWith('$')).map(([k, v]) => [k, v.$value]));
const light = flat(readJSON('tokens/light.json').color), dark = flat(readJSON('tokens/dark.json').color);
const errors = [];

/* ---------- Theme files ---------- */
const THEMEABLE = ['chrome', 'surface', 'raised', 'sunken', 'line', 'line-2', 'control', 'ink', 'ink-2', 'ink-3', 'you-wave', 'jade', 'jade-wave', 'jade-soft', 'on-jade', 'user-bubble'];
const LOCKED = ['cinnabar', 'cinnabar-soft', 'on-cinnabar', 'amber', 'amber-soft', 'overlap'];
const MODES = ['light', 'dark', 'light-hc', 'dark-hc'];
const DEFAULT_THEME = 'celadon';
const SURFACES = ['theme', 'system'];

for (const [mode, values] of [['light', light], ['dark', dark]]) {
  const keys = Object.keys(values);
  for (const k of keys) if (!THEMEABLE.includes(k) && !LOCKED.includes(k)) errors.push(`tokens/${mode}.json: ${k} is neither themeable nor locked; add it to one list in tools/tokens.mjs`);
  for (const k of [...THEMEABLE, ...LOCKED]) if (!keys.includes(k)) errors.push(`tokens/${mode}.json: missing ${k}`);
}

/* ---------- Color math: sRGB <-> OKLab ---------- */
const toLinear = v => (v <= .04045 ? v / 12.92 : ((v + .055) / 1.055) ** 2.4);
const toGamma = v => (v <= .0031308 ? 12.92 * v : 1.055 * v ** (1 / 2.4) - .055);
const rgb = hex => [1, 3, 5].map(i => parseInt(hex.slice(i, i + 2), 16) / 255);
const oklab = hex => {
  const [r, g, b] = rgb(hex).map(toLinear);
  const [l, m, s] = [
    .4122214708 * r + .5363325363 * g + .0514459929 * b,
    .2119034982 * r + .6806995451 * g + .1073969566 * b,
    .0883024619 * r + .2817188376 * g + .6299787005 * b,
  ].map(Math.cbrt);
  return [.2104542553 * l + .793617785 * m - .0040720468 * s, 1.9779984951 * l - 2.428592205 * m + .4505937099 * s, .0259040371 * l + .7827717662 * m - .808675766 * s];
};
const fromOklab = ([L, A, B]) => {
  const [l, m, s] = [L + .3963377774 * A + .2158037573 * B, L - .1055613458 * A - .0638541728 * B, L - .0894841775 * A - 1.291485548 * B].map(v => v ** 3);
  return `#${[
    4.0767416621 * l - 3.3077115913 * m + .2309699292 * s,
    -1.2684380046 * l + 2.6097574011 * m - .3413193965 * s,
    -.0041960863 * l - .7034186147 * m + 1.707614701 * s,
  ].map(v => Math.round(Math.min(1, Math.max(0, toGamma(v))) * 255).toString(16).padStart(2, '0')).join('').toUpperCase()}`;
};
const mix = (a, b, t) => { const [x, y] = [oklab(a), oklab(b)]; return fromOklab(x.map((v, i) => v + (y[i] - v) * t)); };
const hue = hex => { const [, a, b] = oklab(hex); return (Math.atan2(b, a) * 180 / Math.PI + 360) % 360; };
const hueGap = (a, b) => { const d = Math.abs(hue(a) - hue(b)); return Math.min(d, 360 - d); };

// Increased Contrast, for keys a theme leaves out: secondary text steps up one level,
// separators take the next stronger line, the model color moves 25% toward ink.
const deriveHC = t => ({
  'ink-2': mix(t['ink-2'], t.ink, .5), 'ink-3': t['ink-2'],
  line: t['line-2'], 'line-2': t.control, control: mix(t.control, t.ink, .25),
  jade: mix(t.jade, t.ink, .25), 'jade-wave': mix(t['jade-wave'], t.ink, .25),
});

const pascal = s => s.split('-').map(w => w[0].toUpperCase() + w.slice(1)).join('');
const themes = readdirSync(new URL('tokens/themes/', root)).filter(f => f.endsWith('.json')).map(file => {
  const id = file.slice(0, -'.json'.length), where = `tokens/themes/${file}`;
  if (!/^[a-z][a-z0-9]*(-[a-z0-9]+)*$/.test(id)) errors.push(`${where}: the ID must be lowercase words joined by hyphens`);
  const doc = readJSON(where), meta = doc.$extensions?.minicpm ?? {};
  for (const k of ['name', 'nameEn', 'order', 'surfaces']) if (meta[k] === undefined) errors.push(`${where}: missing $extensions.minicpm.${k}`);
  if (meta.surfaces !== undefined && !SURFACES.includes(meta.surfaces)) errors.push(`${where}: surfaces must be ${SURFACES.join(' or ')}`);
  if (meta.order !== undefined && !Number.isInteger(meta.order)) errors.push(`${where}: order must be an integer`);
  for (const group of Object.keys(doc)) if (!group.startsWith('$') && !MODES.includes(group)) errors.push(`${where}: unknown group ${group}; use ${MODES.join(', ')}`);
  const given = Object.fromEntries(MODES.map(m => [m, flat(doc[m])]));
  for (const [mode, values] of Object.entries(given)) {
    for (const [k, v] of Object.entries(values)) {
      if (LOCKED.includes(k)) errors.push(`${where}: ${mode}.${k} is a signal color and is the same in every theme`);
      else if (!THEMEABLE.includes(k)) errors.push(`${where}: ${mode}.${k} is not a themeable key`);
      else if (!/^#[0-9A-Fa-f]{6}$/.test(v)) errors.push(`${where}: ${mode}.${k} must be an opaque #RRGGBB color, got ${v}`);
    }
  }
  // Only themeable keys reach the values, so a rejected key does not also show up as contrast failures.
  const own = mode => Object.fromEntries(Object.entries(given[mode]).filter(([k]) => THEMEABLE.includes(k)));
  const l = { ...light, ...own('light') }, d = { ...dark, ...own('dark') };
  const values = { light: l, dark: d, 'light-hc': { ...l, ...deriveHC(l), ...own('light-hc') }, 'dark-hc': { ...d, ...deriveHC(d), ...own('dark-hc') } };
  return { id, prefix: pascal(id), name: meta.name, nameEn: meta.nameEn, order: meta.order, surfaces: meta.surfaces, description: doc.$description ?? '', values };
}).sort((a, b) => a.order - b.order);

const fallback = themes.find(t => t.id === DEFAULT_THEME);
if (!fallback) errors.push(`tokens/themes/${DEFAULT_THEME}.json is missing; it is the default and the fallback`);
for (const [i, t] of themes.entries()) if (themes.findIndex(u => u.order === t.order) !== i) errors.push(`tokens/themes/${t.id}.json: order ${t.order} is already used`);

/* ---------- Checks ---------- */
const lum = hex => { const [r, g, b] = rgb(hex).map(toLinear); return .2126 * r + .7152 * g + .0722 * b; };
const ratio = (a, b) => { const [x, y] = [lum(a), lum(b)].sort((p, q) => q - p); return (x + .05) / (y + .05); };
const TEXT = 4.5, GRAPHIC = 3;
const PAIRS = [
  ['ink', 'surface', TEXT], ['ink-2', 'surface', TEXT], ['ink-3', 'surface', TEXT], ['ink-3', 'chrome', TEXT], ['ink-3', 'raised', TEXT], ['ink-3', 'sunken', TEXT],
  ['ink', 'user-bubble', TEXT], ['ink-2', 'amber-soft', TEXT], ['ink-2', 'cinnabar-soft', TEXT], ['ink-2', 'jade-soft', TEXT],
  ['jade', 'surface', TEXT], ['jade', 'jade-soft', TEXT], ['on-jade', 'jade', TEXT], ['cinnabar', 'surface', TEXT], ['cinnabar', 'cinnabar-soft', TEXT], ['on-cinnabar', 'cinnabar', TEXT], ['amber', 'amber-soft', TEXT],
  ['jade-wave', 'surface', GRAPHIC], ['you-wave', 'surface', GRAPHIC], ['amber', 'surface', GRAPHIC], ['control', 'surface', GRAPHIC], ['control', 'raised', GRAPHIC],
];
// The model color must not read as a signal: OKLCH hue at least this far from cinnabar and amber.
const HUE = { cinnabar: 60, amber: 40 };

let checked = 0, closest = null;
const contrast = (label, t) => {
  for (const [fg, bg, min] of PAIRS) {
    checked++;
    const r = ratio(t[fg], t[bg]);
    if (r < min) errors.push(`${label}: ${fg} on ${bg} is ${r.toFixed(2)}, needs ${min}`);
  }
};
contrast('tokens/light.json', light);
contrast('tokens/dark.json', dark);
const baseChecked = checked;
for (const t of themes) {
  for (const mode of MODES) {
    const v = t.values[mode], label = `${t.id} ${mode}`;
    contrast(label, v);
    for (const key of ['jade', 'jade-wave']) {
      for (const [signal, min] of Object.entries(HUE)) {
        const gap = hueGap(v[key], v[signal]);
        if (gap < min) errors.push(`${label}: ${key} hue is ${gap.toFixed(0)}° from ${signal}, needs ${min}°`);
        if (!closest || gap - min < closest.gap - closest.min) closest = { label, key, signal, gap, min };
      }
    }
  }
}

/* ---------- Outputs ---------- */
const out = new Map();
const write = (path, text) => out.set(path, text);
const cssVars = (values, keys = Object.keys(values)) => keys.map(k => `--${k}:${values[k]};`).join(' ');

// Prototype: the base :root blocks, one rule set per theme keyed by data-palette, and the list the theme picker reads.
const page = process.argv[2] ?? 'index.html';
let html = readFileSync(new URL(page, root), 'utf8');
const fill = (name, body) => {
  const block = new RegExp(`/\\* tokens:${name} \\*/[\\s\\S]*?/\\* /tokens \\*/`);
  if (!block.test(html)) errors.push(`${page}: missing the /* tokens:${name} */ … /* /tokens */ block`);
  html = html.replace(block, () => `/* tokens:${name} */\n${body}\n  /* /tokens */`);
};
fill('light', `  ${cssVars(light)}`);
fill('dark', `  ${cssVars(dark)}`);
// Every rule carries the whole themeable set, so no value leaks between themes. dark-hc beats dark and light-hc by specificity.
const SELECTORS = { light: id => `:root[data-palette=${id}]`, dark: id => `:root[data-palette=${id}][data-theme=dark]`, 'light-hc': id => `:root[data-contrast=more][data-palette=${id}]`, 'dark-hc': id => `:root[data-contrast=more][data-palette=${id}][data-theme=dark]` };
fill('themes', MODES.flatMap(mode => themes.map(t => `${SELECTORS[mode](t.id)}{${cssVars(t.values[mode], THEMEABLE)}}`)).join('\n'));
const SWATCH = ['chrome', 'surface', 'ink', 'jade', 'user-bubble'];
const palettes = themes.map(t => ({ id: t.id, name: t.name, description: t.description, light: Object.fromEntries(SWATCH.map(k => [k, t.values.light[k]])), dark: Object.fromEntries(SWATCH.map(k => [k, t.values.dark[k]])) }));
fill('palettes', `const DEFAULT_PALETTE = '${DEFAULT_THEME}';\nconst PALETTES = ${JSON.stringify(palettes)};`);
write(page, html);

// Web is paused (docs/07-platforms.md), so it keeps the default theme only. Its theme switch is data-theme, the same as the prototype.
write('apps/web/src/styles/tokens.css', `/* Generated by tools/tokens.mjs from tokens/*.json. Do not edit. */
:root{color-scheme:light; ${cssVars(light)}}
:root[data-theme=dark]{color-scheme:dark; ${cssVars(dark)}}
`);

// iOS. Root colorsets are the default theme's role colors, which system controls and the brand mark use.
// Themes/<Prefix>/<Prefix><Role> holds each theme's content-layer colors. The folders do not provide a namespace,
// so the prefix keeps every name, and every generated asset symbol, unique.
const srgb = hex => {
  const [red, green, blue] = [1, 3, 5].map(i => `0x${hex.slice(i, i + 2).toUpperCase()}`);
  return { color: { 'color-space': 'srgb', components: { alpha: hex.length > 7 ? (parseInt(hex.slice(7, 9), 16) / 255).toFixed(3) : '1.000', blue, green, red } }, idiom: 'universal' };
};
const DARK = { appearance: 'luminosity', value: 'dark' }, HIGH = { appearance: 'contrast', value: 'high' };
const colorset = v => `${JSON.stringify({
  colors: [
    srgb(v.light), { appearances: [DARK], ...srgb(v.dark) },
    ...(v['light-hc'] ? [{ appearances: [HIGH], ...srgb(v['light-hc']) }, { appearances: [DARK, HIGH], ...srgb(v['dark-hc']) }] : []),
  ],
  info: { author: 'xcode', version: 1 },
}, null, 2)}\n`;
const FOLDER = `${JSON.stringify({ info: { author: 'xcode', version: 1 } }, null, 2)}\n`;
const ASSETS = 'apps/ios/MiniCPM/Assets.xcassets/';
const ROOT_COLORS = { AccentColor: 'jade', JadeWave: 'jade-wave', JadeSoft: 'jade-soft', OnJade: 'on-jade', Cinnabar: 'cinnabar', CinnabarSoft: 'cinnabar-soft', Amber: 'amber', AmberSoft: 'amber-soft', YouWave: 'you-wave', Overlap: 'overlap', UserBubble: 'user-bubble' };
const names = new Set();
for (const [name, key] of Object.entries(ROOT_COLORS)) {
  names.add(name);
  // Signal colors have no Increased Contrast values yet; the themeable ones take the default theme's.
  const hc = THEMEABLE.includes(key) && fallback ? { 'light-hc': fallback.values['light-hc'][key], 'dark-hc': fallback.values['dark-hc'][key] } : {};
  write(`${ASSETS}${name}.colorset/Contents.json`, colorset({ light: light[key], dark: dark[key], ...hc }));
}
write(`${ASSETS}Themes/Contents.json`, FOLDER);
for (const t of themes) {
  write(`${ASSETS}Themes/${t.prefix}/Contents.json`, FOLDER);
  for (const key of THEMEABLE) {
    const name = t.prefix + pascal(key);
    if (names.has(name)) errors.push(`tokens/themes/${t.id}.json: asset name ${name} is already used; rename the theme`);
    names.add(name);
    write(`${ASSETS}Themes/${t.prefix}/${name}.colorset/Contents.json`, colorset(Object.fromEntries(MODES.map(m => [m, t.values[m][key]]))));
  }
}

// Swift. The rules layer only knows IDs and asset names; display names live in the app's String Catalog.
const swiftString = s => JSON.stringify(s);
const swiftCase = key => { const p = pascal(key); return p[0].toLowerCase() + p.slice(1); };
const others = themes.filter(t => t !== fallback);
const nameResource = t => `LocalizedStringResource(${swiftString(`theme.${t.id}`)}, defaultValue: ${swiftString(t.name)}, comment: ${swiftString(`Theme name. English: ${t.nameEn}. ${t.description}`)})`;
write('apps/ios/Packages/MiniCPMCore/Sources/MiniCPMCore/ThemeCatalog.generated.swift', `// Generated by tools/tokens.mjs from tokens/themes/*.json. Do not edit.
// Prefs store only the theme ID. The colors are in the app's Asset Catalog under Themes/.

/// Where a theme's content-layer backgrounds come from. \`system\` uses the system backgrounds instead of theme paper.
public enum ThemeSurfaces: String, Sendable {
    case theme, system
}

/// The colors a theme may change. The raw value is the asset-name suffix. The \`jade\` names are historical: they mean the model color.
public enum ThemeRole: String, CaseIterable, Sendable {
${THEMEABLE.map(k => `    case ${swiftCase(k)} = ${swiftString(pascal(k))}`).join('\n')}
}

public struct Theme: Identifiable, Hashable, Sendable {
    public let id: String
    public let order: Int
    public let surfaces: ThemeSurfaces
    let assetPrefix: String

    /// The Asset Catalog color name, for example \`${pascal(DEFAULT_THEME)}Surface\`.
    public func assetName(_ role: ThemeRole) -> String { assetPrefix + role.rawValue }
}

public enum ThemeCatalog {
    public static let defaultID = ${swiftString(DEFAULT_THEME)}

    /// Sorted by \`order\`. Settings show this list; no view keeps its own.
    public static let all: [Theme] = [
${themes.map(t => `        Theme(id: ${swiftString(t.id)}, order: ${t.order}, surfaces: .${t.surfaces}, assetPrefix: ${swiftString(t.prefix)}),`).join('\n')}
    ]

    static let fallback = Theme(id: ${swiftString(DEFAULT_THEME)}, order: ${fallback?.order ?? 0}, surfaces: .${fallback?.surfaces ?? 'theme'}, assetPrefix: ${swiftString(pascal(DEFAULT_THEME))})

    /// An ID this version does not know, say one saved by a newer version, shows the default theme.
    /// The caller keeps the stored ID, so the theme comes back after upgrading again.
    public static func resolve(_ id: String?) -> Theme {
        all.first { $0.id == id } ?? fallback
    }
}
`);
write('apps/ios/MiniCPM/Shared/ThemeNames.generated.swift', `// Generated by tools/tokens.mjs from tokens/themes/*.json. Do not edit.
import Foundation
import MiniCPMCore

extension Theme {
    /// Literal keys, so Xcode extracts them into Localizable.xcstrings. An unknown ID shows the default theme's name.
    var name: LocalizedStringResource {
        switch id {
${others.map(t => `        case ${swiftString(t.id)}: ${nameResource(t)}`).join('\n')}
        default: ${fallback ? nameResource(fallback) : 'LocalizedStringResource(stringLiteral: id)'}
        }
    }
}
`);

/* ---------- Report, then write ---------- */
if (errors.length) {
  for (const e of errors) console.log(`FAIL ${e}`);
  console.log(`${errors.length} problems. Nothing written.`);
  process.exit(1);
}
rmSync(new URL(`${ASSETS}Themes/`, root), { recursive: true, force: true });
for (const [path, text] of out) {
  const url = new URL(path, root);
  mkdirSync(new URL('.', url), { recursive: true });
  writeFileSync(url, text);
}
console.log(`contrast: ${checked} pairs pass (default ${baseChecked}, then ${themes.length} themes × ${MODES.length} modes)`);
if (closest) console.log(`hue: closest model color is ${closest.label} ${closest.key}, ${closest.gap.toFixed(0)}° from ${closest.signal} (needs ${closest.min}°)`);
console.log(`wrote ${page}, tokens.css, ${Object.keys(ROOT_COLORS).length} root and ${themes.length * THEMEABLE.length} theme colorsets, 2 Swift files`);
const strings = readJSON('apps/ios/MiniCPM/Localizable.xcstrings').strings;
const untranslated = themes.filter(t => Object.keys(strings[`theme.${t.id}`]?.localizations ?? {}).length < 4).map(t => `theme.${t.id}`);
if (untranslated.length) console.log(`note: Localizable.xcstrings needs all four display names for ${untranslated.join(', ')}`);
