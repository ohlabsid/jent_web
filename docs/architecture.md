# Architecture

Personal portfolio site ("Pritjent") as a fake macOS desktop on the web.
Flutter + `flutter_bloc` (BLoC = the ViewModel layer) + GetIt +
injectable codegen. Deployed to Firebase Hosting (`me-jent`).

## Folder map

```
lib/
  main.dart                # DI init -> Supabase init -> runApp
  app.dart                 # Theme + l10n + router only (no blocs here)
  router/                  # go_router: ignite -> home
  core/                    # theme, constants, shared window/dock widgets,
                           # supabase config, base_page
  data/                    # datasources + repository impls
  domain/                  # entities, repository interfaces, usecases
  di/                      # injection.dart + GENERATED injection.config.dart
  gen/  l10n/              # generated assets + localizations (en/id)
  features/<name>/         # ONE self-contained feature each:
    bloc/                  #   <name>_bloc.dart, <name>_event.dart,
                           #   <name>_state.dart (1 bloc per feature, no god-blocs)
    view/  widgets/        #   overlays, windows, small widgets
test/features/<name>/      # mirrors lib/features 1:1
test/domain/               # entity unit tests
integration_test/          # full-app journeys (headless web via drive)
test_driver/               # integration_test driver entry
docs/                      # AI/human guide (read before working here)
AGENTS.md                  # agent entry point -> docs first
assets/
  photos_general/          # public album (wrong-PIN guests can view)
  photos_private/          # PIN-only album
```

## Layer rules

- `view/` may import its own `bloc/` + `core/` + `domain/` + `l10n`.
  Features NEVER import each other — except `desktop`, which is the
  only cross-feature reader (the dock).
- `bloc/` may import `domain/`, `data/`, `core/constants`.
  Blocs never import widgets.
- `data/` implements `domain/` repository interfaces.
- New injectable class → rerun codegen (see `workflows.md`).

## Runtime composition (`features/desktop/view/home_page.dart`)

`MultiBlocProvider` creates exactly 5 blocs:
`WallpaperBloc, MailBloc, MusicBloc, PhotosBloc, NotesBloc`.
Each overlay reads ONLY its own bloc. The entrance animation
controller is driven by `MailBloc.isShowWindow`.

## Feature inventory (details in `features.md`)

| Feature | Bloc | Unlock model |
|---|---|---|
| wallpaper | WallpaperBloc | none (6s rotation timer) |
| mail | MailBloc (+SendEmailUseCase) | none |
| music | MusicBloc (just_audio + Supabase library) | none |
| photos | PhotosBloc | PIN every open; guest sees general album |
| notes | NotesBloc (+Supabase sync) | PIN every open; guest sees General folder, read-only |
| dock | no bloc (reads 4 blocs) | n/a |
