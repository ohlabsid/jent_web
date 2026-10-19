# Conventions & Gotchas

Learned the hard way — read before writing code or tests.

## Code
- One bloc per feature (`features/<name>/bloc/`). Never reintroduce a
  god-bloc; features must not import each other (dock is the only
  exception).
- UI rules: flat design, NO glow effects (`BoxShadow` with color,
  `RadialGradient` accents, backdrop blur on cards). Neutral drop
  shadows for window elevation are fine.
- Shared window chrome lives in `core/widgets/window/` — reuse
  `WindowTitleBar` + `WindowResizeHandle`, don't rebuild them.
- Overlays keep window geometry in a local `ValueNotifier<Rect?>`
  (null = preset); bloc holds only open/minimized/expanded/locked.
- Reordered `Stack` children need stable keys, or Flutter remounts
  them and destroys their `State` on every reorder (see stacking
  order in `features.md`).
- `BlocSelector` with a `List` result rebuilds on EVERY emit (identity
  equality) — use records or `context.select` instead.
- **postgrest-dart `order()` defaults to DESCENDING** (opposite of SQL
  and of postgrest-js). Always pass `ascending: true` where you mean
  ascending, or playlists play backwards / lists render newest-first.
- Supabase calls swallow failures: the datasources return `null`/`false`
  instead of throwing, so a broken define or bad RLS looks exactly like
  "empty backend" (demo music catalog, seed notes). When a backend
  feature seems dead, check the Network tab for the REST call before
  touching code.
- Flutter Web has **no HTML DOM for your widgets** — CanvasKit paints
  everything. Third-party JS widgets (hCaptcha) therefore need a real
  `<div>` hosted via `HtmlElementView` + `platformViewRegistry`; a
  `<div class="...">` + script-tag "drop-in" silently does nothing.
  JS options with kebab-case keys need `JSObject()` + `setProperty`,
  and `dart:js_util` is web-only (lint) — use `js_interop_unsafe`.
- Keep the platform view type stable per controller instance
  (`hcaptcha-${counter++}`) and register the factory once, or every
  rebuild recreates the view and duplicate registration throws.
- Text changes need BOTH `app_en.arb` AND `app_id.arb` + regen.

## Deploys
- Canonical live site is **https://jentweb.web.app** (`.firebaserc`
  default + workflow `projectId`). `me-jent.web.app` is a legacy
  manual deployment kept only for the old domain — never test on it,
  it can be many features behind.
- Suspect a stale build? Compare a table name from
  `lib/data/datasources/` against the served bundle:
  `curl -s https://jentweb.web.app/main.dart.js | grep -c music_tracks`
  (`0` = the deployed build predates the Supabase music feature).
- Firebase hosts the Flutter **service worker**, so a stale bundle can
  survive a deploy; hard-reload when verifying a new build.

## Tests (flutter_test + bloc_test + mocktail)
- After `bloc.add(...)`, pump TWICE (`pump()` + `pump(duration)`)
  before asserting: one pump rebuilds + starts implicit animations,
  the second settles them. Single-pump asserts read stale sizes.
- Quiesce timers before teardown or the test fails with "Timer is
  still pending": `CloseMusicPlayer` (sim timer), 1s pump (notes
  800ms debounce), music `ToggleMusicPlayback` off, and the mail
  window's 2s sent-banner timer (cancel it in `dispose`).
- Hidden PIN fields (`Opacity 0`) still accept `enterText`.
- `tester.drag` on a resize handle: deltas accumulate, then pump
  twice to measure.
- Hit-test warnings on taps are benign when an ancestor handles the
  tap (e.g. text inside a `GestureDetector`).
- Widget harnesses must include ALL overlays the flow touches
  (e.g. `NotesOverlay` + `NotesPinOverlay`), with l10n delegates +
  `Locale('en')`.
- New `@injectable` bloc needs its deps mocked in widget tests
  (`statusStream`/`playerState` → empty streams or they hang).
- Keep temp live-network tests OUT of the suite (flutter_test
  blocks real HTTP; suite must stay hermetic/offline).
