// Turns downloaded audio bytes into something just_audio can play.
// Web has no filesystem, so bytes become a blob URL; native targets
// get a temp file. Selected by platform at compile time.
export 'playable_source_io.dart'
    if (dart.library.js_interop) 'playable_source_web.dart';
