import 'dart:ui' show ImageFilter;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';

import '../theme.dart';

/// Picks a readable accent colour out of the artwork.
///
/// Lightness and saturation are clamped so white button text and nearby labels
/// keep contrast no matter how bright or washed-out the poster is.
Future<Color?> accentFromArtwork(String? url) async {
  if (url == null || url.trim().isEmpty) return null;
  try {
    final palette = await PaletteGenerator.fromImageProvider(
      CachedNetworkImageProvider(url),
      size: const Size(96, 144),
      maximumColorCount: 8,
    );
    final color =
        palette.vibrantColor?.color ??
        palette.darkVibrantColor?.color ??
        palette.dominantColor?.color;
    if (color == null) return null;
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withSaturation(hsl.saturation.clamp(0.45, 0.9))
        .withLightness(hsl.lightness.clamp(0.42, 0.62))
        .toColor();
  } catch (_) {
    return null;
  }
}

/// Blurred artwork with an accent glow, used behind detail pages.
///
/// The scrim is intentionally strong: fully opaque by ~58% of the height, so
/// body copy sits on the app background rather than on the poster.
class AmbientBackdrop extends StatelessWidget {
  const AmbientBackdrop({super.key, required this.image, required this.accent});

  final String? image;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (image != null && image!.isNotEmpty)
              Positioned.fill(
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(
                    sigmaX: 46,
                    sigmaY: 46,
                    tileMode: TileMode.decal,
                  ),
                  child: Opacity(
                    opacity: 0.45,
                    child: CachedNetworkImage(
                      imageUrl: image!,
                      fit: BoxFit.cover,
                      memCacheWidth: 480,
                      placeholder: (_, _) => const SizedBox.shrink(),
                      errorWidget: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -1.15),
                  radius: 1.5,
                  colors: [accent.withValues(alpha: 0.32), Colors.transparent],
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.background.withValues(alpha: 0.35),
                    AppColors.background.withValues(alpha: 0.88),
                    AppColors.background,
                    AppColors.background,
                  ],
                  stops: const [0.0, 0.34, 0.6, 1.0],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
