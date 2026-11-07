# MiniCPM Design

Design source for the MiniCPM client: a single-file web prototype, design docs in Chinese, and design tokens. The final product is native UI on Android, iOS, macOS and Web. First real clients live in `apps/`.

Current stage: draft. Copy is not final, the web prototype is the main test bed, and device testing is deferred.

Read `README.md` first, then `docs/01-philosophy.md`. `docs/10-decisions.md` records settled and open decisions; do not reverse a settled one without the user.

## Rules

- The prototype is a design artifact. It simulates behavior; do not add real backends, frameworks or build steps.
- Native platforms use system controls. The prototype defines structure, states, semantics and copy; its styling is final only for Web. Do not design simulated OS chrome.
- Keep features and settings unless the user removes them; trimming happens after team discussion.
- Default UI uses plain language. Technical terms stay behind advanced settings and the "show technical info" switch.
- Privacy copy must stay true: when `isRemote()`, every on-device claim changes to name the destination.
- Scene ids (`life`, `work`, `game`, `community`) are stable; display names are separate.

## Working in the prototype

- The prototype is `index.html`, the only copy kept here. Use git history to roll back. Pushing to `main` publishes it to GitHub Pages.
- One DOM and one state serve both forms. `COMPACT_QUERY` in the script mirrors the CSS "Compact form" block; change them together.
- Color values live in `tokens/*.json`. Run `node tools/tokens.mjs` to sync them into the `/* tokens:* */` blocks and `apps/`, and check contrast. Do not edit those blocks or the generated files by hand.
- Every state must open from a query parameter. When adding one, update the boot comment, `states.html` and `docs/05-states.md`.
- Check changes by rendering at 1440, 390 and 360 wide, in light and dark.

## Working in the clients

- `apps/web` (Vite, React, TypeScript) and `apps/ios` (SwiftUI, iOS 27) follow `docs/11-client-architecture.md`. The prototype rules against frameworks and build steps do not apply here.
- The prototype stays the spec. Behavior, states and copy come from it and `docs/`; a change of behavior lands in the design first or together.
- First stage only: vision models and text. Live and omni entries stay hidden by model capability.
- Rules live in the UI-free layer (`apps/web/src/core`, `MiniCPMCore`) and mirror each other. Change a rule on both sides.
- `Engine` and `ModelStore` are the only seam for inference. Failures never switch the run location.
- Web: `npm test`, `npm run build`, and render at 1440, 390 and 360 in light and dark. iOS: `swift test` in the package; the app target builds only on a Mac.

## Reference repos

- `refs/` holds upstream client implementations as read-only submodules (`refs/README.md`). Read them for structure, states and copy; never edit or commit inside them, and never treat their styling as final.

## Docs

Write docs in Simplified Chinese. Mark platform claims that need device testing with **[待实测]**.
