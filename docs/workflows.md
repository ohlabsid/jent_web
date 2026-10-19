# Workflows

## Local dev (all features live)
```sh
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8080 \
  "--dart-define=WEB3FORMS_KEY=..." \
  "--dart-define=SUPABASE_URL=..." \
  "--dart-define=SUPABASE_ANON_KEY=..."
```

## Tests & analysis
```sh
flutter test                    # full suite (~105 tests)
flutter test test/features/<name>/
flutter analyze
```

## Integration tests (real app on headless web)
```sh
# One-time setup: chromedriver matching the installed Chrome must
# serve on :4444 (macOS cannot run this app: just_audio uses
# platform audio on native).
chromedriver --port=4444
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/app_journey_test.dart -d web-server
```
Journey covers: ignite -> home, mail compose (expects the no-key
error state), photos PIN -> gallery -> viewer, notes wrong-PIN ->
guest album, music library window opens with the demo catalog. No secrets needed; external calls
fail gracefully by design. Never assert hardcoded UI strings here —
the runner inherits the machine locale (use keys/types/icons).

## Codegen (after adding `@injectable`/`@lazySingleton`/l10n keys)
```sh
dart run build_runner build --delete-conflicting-outputs
flutter gen-l10n
```
`flutter gen-l10n` reads `l10n.yaml`; template file is `app_id.arb`
— add keys to BOTH `app_en.arb` and `app_id.arb` first.

## Release deploy (Firebase Hosting, project `jentweb`)
```sh
flutter build web --release --base-href / --dart-define=... (same three)
firebase deploy --only hosting --project jentweb
```
Live at `https://jentweb.web.app`. CI (`.github/workflows/`) does the
same: it reads these repo secrets and injects them as `--dart-define`s
via `env` (quoted, so special characters are safe):

| Repo secret | Maps to define |
|---|---|
| `SUPABASE_URL` | `SUPABASE_URL` (notes + music catalog) |
| `SUPABASE_ANON_KEY` | `SUPABASE_ANON_KEY` |
| `WEB3FORMS_KEY` | `WEB3FORMS_KEY` (contact form) |

A secret that is missing expands to an empty define and the app
degrades gracefully (see `backend-and-secrets.md`). Add/rotate them
under Settings > Secrets and variables > Actions. Deploys also need
`FIREBASE_SERVICE_ACCOUNT_ME_JENT` (project `jentweb`) and use
`DISCORD_WEBHOOK_URL` for notifications.

## Music upload (Supabase `music` bucket + catalog rows)
```sh
# 1. Drop .mp3 files in music_upload/ and fill tracks.json
#    (fields documented in music_upload/README.md).
# 2. Preview the plan without touching Supabase:
dart run tool/upload_music.dart --dry-run
# 3. Push (needs the service_role key — never commit it):
SUPABASE_URL=https://xyz.supabase.co \
SUPABASE_SERVICE_ROLE_KEY=eyJ... \
dart run tool/upload_music.dart
```
MP3s are gitignored; manifest + script are committed. Re-running
overwrites files and upserts rows. Then open the in-app music
window and hit refresh.

## Assets
`pubspec.yaml` lists `assets/` BUT subdirectories need explicit
entries (`assets/photos_general/`, `assets/photos_private/`).
New photo folders: create dir + pubspec entry + paths in
`core/constants/app_images.dart` (see folder READMEs).
