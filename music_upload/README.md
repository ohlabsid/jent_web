# music_upload/

Drop MP3s here and describe them in `tracks.json`, then run the
uploader. Files in this folder are **never** bundled into the app
(they live outside `assets/`) — they are pushed to the Supabase
`music` storage bucket, and the rows land in `music_tracks` /
`music_playlists` / `music_playlist_tracks`.

## Steps

1. Copy your `.mp3` files into this folder.
2. Edit `tracks.json` (see the field table below).
3. Get the **service_role** key: Supabase dashboard > Project
   Settings > API > `service_role` (**secret** — never commit it,
   never bake it into the app; it bypasses RLS).
4. Run, with the key passed via environment (not CLI args, so it
   stays out of shell history on shared machines you can also export
   it first):

```sh
SUPABASE_URL=https://xyz.supabase.co \
SUPABASE_SERVICE_ROLE_KEY=eyJ... \
dart run tool/upload_music.dart
```

Preview without touching Supabase:

```sh
dart run tool/upload_music.dart --dry-run
```

## tracks.json fields

Top level:

| Field | Required | Notes |
|---|---|---|
| `tracks` | yes | list of track objects (below) |
| `playlists` | no | list of `{id, name, sort_order?}` |

Per track:

| Field | Required | Default | Notes |
|---|---|---|---|
| `file` | yes | — | `.mp3` filename in this folder |
| `title` | yes | — | shown in the player |
| `artist` | no | `""` | |
| `album` | no | `""` | |
| `duration_seconds` | yes | — | integer; find it with `afinfo -b <file> \| grep "estimated duration"` on macOS (first number), or any media player |
| `sort_order` | no | file order (1, 2, …) | library order |
| `artwork_url` | no | `""` | cover image URL (any public URL, or a public Supabase storage file URL); empty shows the note placeholder |
| `playlists` | no | `[]` | playlist `id`s from the top-level list; position follows track order |

The storage path is the plain filename (`audio_path` in
`music_tracks`). Re-running overwrites the file and upserts the rows,
so edits are safe to re-push. Removing a track from `tracks.json`
does **not** delete the remote file/row — delete those in the
Supabase dashboard.
