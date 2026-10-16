# Backend & Secrets

No secret is ever committed. Web build/run takes everything via
`--dart-define`. CI sources them from GitHub Actions secrets.

## `--dart-define` variables

| Var | Used by | Notes |
|---|---|---|
| `VAULT_PIN` | photos + notes gates | default `1234` (`core/constants/vault_pin.dart`) |
| `SUPABASE_URL` | `core/supabase/supabase_config.dart` | e.g. `https://xyz.supabase.co` |
| `SUPABASE_ANON_KEY` | same | publishable/anon key (public by design) |
| `WEB3FORMS_KEY` | contact form on web | free key from web3forms.com |
| `EMAIL_USERNAME/PASSWORD/RECIPIENT` | SMTP path (native only) | App Password, not login password |

Missing defines = safe fallback: Supabase skipped (local seeds),
Web3Forms throws a clear `StateError` surfaced as the form's error
state, music keeps the bundled demo catalog (streaming needs network).

## Email sending (contact form)
- **Web**: `EmailDatasource` POSTs JSON to Web3Forms. Visitor address
  goes in the `email` field → shows as reply-to in your inbox. Gmail
  may spam-filter first messages: mark "not spam" + filter
  `never send to spam`.
- **Native**: Gmail SMTP via `mailer` (`gmail(username, password)`),
  sender = your account, visitor in `Reply-To` + body. Browsers block
  SMTP sockets, so this path can never run on web.
- Deploy needs `WEB3FORMS_KEY` in the build (see `workflows.md`).

## Supabase (`notes` table)
```sql
create table notes (
  id text primary key,
  folder text not null default 'notes',
  body text not null default '',
  updated_at timestamptz not null default now()
);
alter table notes enable row level security;
create policy "anon all" on notes
  for all to anon using (true) with check (true);
```
Code: `NotesRemoteDataSource` (offline-safe: returns `null`/`false`
when unconfigured/offline). PIN gate is UI-level only — anon-key
holders could technically write; tighten RLS / add Auth before
sensitive use. Folder `general` = guest-visible; other folders private.

## Supabase (`music_tracks` + `music_playlists` tables, `music` bucket)

Run once in the SQL editor, then create a **public** Storage bucket
named `music` (Storage > New bucket). Upload MP3s there, then insert
rows pointing at them via `audio_path` (the bucket-relative file
path, e.g. `ghibli-no-umi.mp3`). The app resolves public URLs itself.

```sql
create table music_tracks (
  id text primary key,
  title text not null,
  artist text not null default '',
  album text not null default '',
  duration_seconds int not null default 0,
  audio_path text not null default '',
  artwork_url text not null default '',
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);
create table music_playlists (
  id text primary key,
  name text not null,
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);
create table music_playlist_tracks (
  playlist_id text not null references music_playlists(id)
    on delete cascade,
  track_id text not null references music_tracks(id)
    on delete cascade,
  position int not null default 0,
  primary key (playlist_id, track_id)
);
alter table music_tracks enable row level security;
alter table music_playlists enable row level security;
alter table music_playlist_tracks enable row level security;
create policy "anon read tracks" on music_tracks
  for select to anon using (true);
create policy "anon read playlists" on music_playlists
  for select to anon using (true);
create policy "anon read playlist tracks" on music_playlist_tracks
  for select to anon using (true);
-- Storage > Policies on `storage.objects`: new SELECT policy for
-- anon `using (bucket_id = 'music')` so the MP3s stream publicly.
```

Code: `MusicRemoteDataSource` (offline-safe: returns `null` when
unconfigured/offline; `MusicBloc` keeps the demo catalog then).
Unlike notes, music is **read-only** from the app — no anon
insert/update/delete policies, so uploads and row edits stay
dashboard-side (owner login). Sidebar playlists come from
`music_playlists` + `music_playlist_tracks(track_id, position)`.

To publish songs without touching the dashboard SQL: drop MP3s in
`music_upload/`, fill `tracks.json`, and run
`tool/upload_music.dart` (needs `SUPABASE_SERVICE_ROLE_KEY`;
see `music_upload/README.md` and `docs/workflows.md`).
