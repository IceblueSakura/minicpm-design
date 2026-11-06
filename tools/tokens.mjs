#!/usr/bin/env node
// Writes tokens/{light,dark}.json into the prototype's :root blocks, then checks WCAG contrast.
// Usage: node tools/tokens.mjs [prototype.html]
import { readFileSync, writeFileSync } from 'node:fs';

const root = new URL('..', import.meta.url);
const read = name => JSON.parse(readFileSync(new URL(`tokens/${name}.json`, root))).color;
const flat = group => Object.fromEntries(Object.entries(group).filter(([k]) => !k.startsWith('$')).map(([k, v]) => [k, v.$value]));
const light = flat(read('light')), dark = flat(read('dark'));

const page = new URL(process.argv[2] ?? 'index.html', root);
let html = readFileSync(page, 'utf8');
for (const [mode, values] of [['light', light], ['dark', dark]]) {
  const css = Object.entries(values).map(([k, v]) => `--${k}:${v};`).join(' ');
  const block = new RegExp(`/\\* tokens:${mode} \\*/[\\s\\S]*?/\\* /tokens \\*/`);
  if (!block.test(html)) throw new Error(`missing tokens:${mode} block`);
  html = html.replace(block, `/* tokens:${mode} */\n  ${css}\n  /* /tokens */`);
}
writeFileSync(page, html);

const lum = hex => {
  const [r, g, b] = [1, 3, 5].map(i => parseInt(hex.slice(i, i + 2), 16) / 255).map(v => (v <= .03928 ? v / 12.92 : ((v + .055) / 1.055) ** 2.4));
  return .2126 * r + .7152 * g + .0722 * b;
};
const ratio = (a, b) => { const [x, y] = [lum(a), lum(b)].sort((p, q) => q - p); return (x + .05) / (y + .05); };
const TEXT = 4.5, GRAPHIC = 3;
const PAIRS = [
  ['ink', 'surface', TEXT], ['ink-2', 'surface', TEXT], ['ink-3', 'surface', TEXT], ['ink-3', 'chrome', TEXT], ['ink-3', 'raised', TEXT], ['ink-3', 'sunken', TEXT],
  ['ink', 'user-bubble', TEXT], ['ink-2', 'amber-soft', TEXT], ['ink-2', 'cinnabar-soft', TEXT], ['ink-2', 'jade-soft', TEXT],
  ['jade', 'surface', TEXT], ['jade', 'jade-soft', TEXT], ['on-jade', 'jade', TEXT], ['cinnabar', 'surface', TEXT], ['cinnabar', 'cinnabar-soft', TEXT], ['on-cinnabar', 'cinnabar', TEXT], ['amber', 'amber-soft', TEXT],
  ['jade-wave', 'surface', GRAPHIC], ['you-wave', 'surface', GRAPHIC], ['amber', 'surface', GRAPHIC], ['control', 'surface', GRAPHIC], ['control', 'raised', GRAPHIC],
];
let failed = 0;
for (const [mode, t] of [['light', light], ['dark', dark]]) {
  for (const [fg, bg, min] of PAIRS) {
    const r = ratio(t[fg], t[bg]);
    if (r < min) { failed++; console.log(`FAIL ${mode} ${fg} on ${bg}: ${r.toFixed(2)} < ${min}`); }
  }
}
console.log(`${page.pathname.split('/').pop()} synced, ${PAIRS.length * 2 - failed}/${PAIRS.length * 2} contrast pairs pass`);
process.exitCode = failed ? 1 : 0;
