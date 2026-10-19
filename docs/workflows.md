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

## Release deploy (Dokploy on the VPS)
```sh
flutter build web --release --base-href / --dart-define=... (same three)
docker build -t jent_web .      # nginx + build/web, see Dockerfile
docker run -p 8080:80 jent_web  # local smoke check of the same image
```
CI (`.github/workflows/deploy-dokploy.yml`) does this on every push to
main: builds the bundle from the repo secrets, pushes
`ghcr.io/ohlabsid/jent_web:{latest,<sha>}`, then curls the Dokploy
webhook so the VPS re-pulls `latest`. The VPS never builds anything —
no Flutter SDK, no RAM pressure, secrets stay in GitHub.

| Repo secret | Used for |
|---|---|
| `SUPABASE_URL` | `--dart-define=SUPABASE_URL` (notes + music catalog) |
| `SUPABASE_ANON_KEY` | `--dart-define=SUPABASE_ANON_KEY` |
| `WEB3FORMS_KEY` | `--dart-define=WEB3FORMS_KEY` (contact form) |
| `DOKPLOY_WEBHOOK_URL` | redeploy trigger (app > General: Auto Deploy on; webhook URL is in the Deployments tab) |
| `DISCORD_WEBHOOK_URL` | success/failure notifications |

The GHCR package is private; Dokploy pulls it through a PAT with
`read:packages` stored in Dokploy's registry settings. A missing
secret expands to an empty define and the app degrades gracefully
(see `backend-and-secrets.md`). Add/rotate secrets under
Settings > Secrets and variables > Actions.

### First-time Dokploy setup (web UI)
1. Projects → Create (`jentweb`) → Create Resource → Application,
   source **Docker Image**, image `ghcr.io/ohlabsid/jent_web:latest`,
   port **80**. The package must be public, or add a `read:packages`
   PAT under Dokploy → Settings → Registry.
2. App → Domains → generate a free `traefik.me` domain (or attach a
   custom one — Let's Encrypt is automatic). Domain-less alternative:
   expose a port under Advanced Settings → Ports.
3. App → General → toggle Auto Deploy on; Deployments tab → copy the
   webhook URL → repo secret `DOKPLOY_WEBHOOK_URL`. Push to main and
   the whole pipeline runs.

## Firebase fallback (manual only)
`.github/workflows/deploy-hosting.yml` no longer runs on push: trigger
it by hand from the Actions tab to republish `https://jentweb.web.app`
(needs `FIREBASE_SERVICE_ACCOUNT_ME_JENT`). Until then that site stays
frozen at the last deploy.

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
