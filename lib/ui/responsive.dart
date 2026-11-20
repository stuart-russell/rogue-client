import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Layout breakpoints. The app was designed for desktop/TV; phones need a
/// different information density and nav model.
const double kCompactBreakpoint = 700;
const double kWideBreakpoint = 1000;

bool isCompact(BuildContext context) =>
    MediaQuery.sizeOf(context).width < kCompactBreakpoint;

/// Android TV uses the wide/desktop layout but has much less vertical room
/// than a desktop window, so detail pages keep a shorter top banner.
bool isTv(BuildContext context) =>
    defaultTargetPlatform == TargetPlatform.android &&
    MediaQuery.sizeOf(context).width >= 900;

/// Horizontal page padding: tighter on phones where 26 px each side wastes
/// a seventh of the screen.
double pagePadding(BuildContext context) => isCompact(context) ? 16 : 26;

/// Top padding of a page's content area.
double pageTopPadding(BuildContext context) => isCompact(context) ? 12 : 22;

/// Bottom padding that clears the phone navigation bar / gesture area.
double pageBottomPadding(BuildContext context) => isCompact(context) ? 12 : 0;
