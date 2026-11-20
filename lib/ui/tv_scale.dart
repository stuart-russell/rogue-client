import 'package:flutter/widgets.dart';

/// Shrinks the whole app for a 10-foot UI.
///
/// The app's spacing and type sizes are shared with desktop, so reducing each
/// one by hand is error-prone. Instead this gives the app a slightly larger
/// logical canvas and fits it into the physical screen, which scales text,
/// cards and padding together.
class TvScale extends StatelessWidget {
  const TvScale({super.key, required this.child, this.scale = 0.9});

  final Widget child;
  final double scale;

  @override
  Widget build(BuildContext context) {
    if (scale >= 1) return child;

    final media = MediaQuery.of(context);
    final size = media.size;
    final logical = Size(size.width / scale, size.height / scale);

    return ClipRect(
      child: FittedBox(
        fit: BoxFit.fill,
        child: SizedBox(
          width: logical.width,
          height: logical.height,
          child: MediaQuery(
            data: media.copyWith(
              size: logical,
              devicePixelRatio: media.devicePixelRatio * scale,
              padding: media.padding / scale,
              viewPadding: media.viewPadding / scale,
              viewInsets: media.viewInsets / scale,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
