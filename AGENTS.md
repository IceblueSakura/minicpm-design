# MiniCPM Design

Design source for the MiniCPM client: a single-file web prototype, design docs in Chinese, and design tokens. UI/UX scope covers iOS, Android, macOS, Windows, Linux and Web; Windows and Linux currently use Web delivery. Native clients use platform controls. First client skeletons live in `apps/`.

Project goal: demonstrate and advance OpenBMB's LES-led on-device inference across platforms, embracing useful new technology. Privacy-first scenarios make that capability useful. Evaluate performance, research contribution and maintainability rather than optimizing primarily for the fastest release.

Current stage: UI/UX draft and client skeletons; no real inference backend has been selected or integrated. Work runs on two decoupled tracks (see `docs/14-roadmap.md`):
- **UI/UX & Client Track (current workspace focus):** the macOS and iOS apps only, planned to pass App Store review. Android, Windows, Linux and Web are paused: keep their existing design and code, but do not update them alongside new work.
- **Backend Research & Experiment Track (isolated in `backend/`):** comparing C++ LES, hybrid Apple acceleration and Core AI via discriminating experiments before any `Engine` integration. Global App Store release (excluding mainland China initially) remains the first release target once both tracks converge.

Copy is not final, and the web prototype is the main UI test bed. A client install during development uses free signing on personal devices only. Paid enrollment, TestFlight, and submission wait until the first release. See `docs/12-compliance.md` and `docs/13-release-and-store-policy.md`.

Read `README.md` first, then `docs/01-philosophy.md`. For planning or backend work, also read `docs/14-roadmap.md`. `docs/10-decisions.md` records settled and open decisions; do not reverse a settled one without the user.

## Rules

- The prototype is a design artifact. It simulates behavior; do not add real backends, frameworks or build steps.
- Native platforms use system controls. The prototype defines structure, states, semantics and copy; its styling is final only for Web. Do not design simulated OS chrome.
- Keep features and settings unless the user removes them; trimming happens after team discussion.
- Primary users are technically curious people who want to see and tune on-device performance; people who only want a private task done must still succeed without touching a parameter. Disclose in layers (`docs/01-philosophy.md` principle 2, `docs/03-structure.md#运行参数与测量`): a one-line measurement by default, run details one tap away, presets, then per-parameter controls. Main copy stays plain; technical names appear only as small secondary labels and hide with the "show technical info" switch.
- Privacy copy must stay true: when `isRemote()`, every on-device claim changes to name the destination.
- No paid features and no tracking. On-device inference is primary. The online fallback stays off until the user consents. Privacy, terms, and support URLs stay in one placeholder config until release. Mainland China is out of scope until the open questions in `docs/13-release-and-store-policy.md` are resolved.
- Scene ids (`life`, `work`, `game`, `community`) are stable; display names are separate.

## Working in the prototype

- The prototype is `index.html`, the only copy kept here. Use git history to roll back. Publishing to GitHub Pages is manual: run the `pages.yml` workflow on `main`; pushes alone do not publish.
- One DOM and one state serve both forms. `COMPACT_QUERY` in the script mirrors the CSS "Compact form" block; change them together.
- Color values live in `tokens/*.json`, themes in `tokens/themes/*.json` (rules in `docs/02-design-language.md#扩展接口`). Run `node tools/tokens.mjs`: it checks contrast and theme rules, and writes the `/* tokens:* */` blocks and `apps/` only when every check passes. Do not edit those blocks or the generated files (`*.colorset`, `Themes/`, `*.generated.swift`, `tokens.css`) by hand.
- Every state must open from a query parameter. When adding one, update the boot comment, `states.html` and `docs/05-states.md`.
- Check changes by rendering at 1440, 390 and 360 wide, in light and dark.

## Working in the clients

- `apps/web` (Vite, React, TypeScript), `apps/ios` (SwiftUI, iOS 27) and the planned separate `apps/macos` (SwiftUI, macOS 27, sharing `MiniCPMCore`) follow `docs/11-client-architecture.md`. The prototype rules against frameworks and build steps do not apply here.
- The prototype stays the spec. Behavior, states and copy come from it and `docs/`; a change of behavior lands in the design first or together.
- First stage only: vision models and text. Live and omni entries stay hidden by model capability.
- Rules live in the UI-free layer (`apps/web/src/core`, `MiniCPMCore`) and mirror each other. Change a rule on both sides.
- `Engine` and `ModelStore` are the only seam for inference. Failures never switch the run location.
- Web: `npm test`, `npm run build`, and render at 1440, 390 and 360 in light and dark. iOS builds only on macOS: `swift test` in the package and `xcodebuild analyze` for the app.

## Reference repos

- `refs/` holds upstream client implementations as read-only submodules (`refs/README.md`). Read them for structure, states and copy; never edit or commit inside them, and never treat their styling as final.

## Docs

Write docs in Simplified Chinese. Mark platform claims that need device testing with **[待实测]**.
