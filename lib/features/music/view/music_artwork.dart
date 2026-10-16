import 'package:flutter/material.dart';

/// Track artwork thumbnail: rounded image from [artworkUrl], falling
/// back to a music-note placeholder when the URL is empty or fails
/// to load (offline, 404, hermetic widget tests).
class TrackArtwork extends StatelessWidget {
  final String artworkUrl;
  final double size;
  final double radius;

  const TrackArtwork({
    super.key,
    required this.artworkUrl,
    this.size = 44,
    this.radius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFE8EAED),
        borderRadius: BorderRadius.circular(radius),
      ),
      clipBehavior: Clip.antiAlias,
      child: artworkUrl.isEmpty
          ? Icon(
              Icons.music_note_rounded,
              color: const Color(0xFF9AA0A6),
              size: size * 0.5,
            )
          : Image.network(
              artworkUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Icon(
                Icons.music_note_rounded,
                color: const Color(0xFF9AA0A6),
                size: size * 0.5,
              ),
            ),
    );
  }
}
