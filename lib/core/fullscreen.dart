import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

final class _Rect extends Struct {
  @Int32()
  external int left;
  @Int32()
  external int top;
  @Int32()
  external int right;
  @Int32()
  external int bottom;
}

final class _MonitorInfo extends Struct {
  @Uint32()
  external int cbSize;
  external _Rect rcMonitor;
  external _Rect rcWork;
  @Uint32()
  external int dwFlags;
}

typedef _IntPtr0 = IntPtr Function();
typedef _Int0 = int Function();
typedef _GetLongPtr = IntPtr Function(IntPtr, Int32);
typedef _GetLongPtrDart = int Function(int, int);
typedef _SetLongPtr = IntPtr Function(IntPtr, Int32, IntPtr);
typedef _SetLongPtrDart = int Function(int, int, int);
typedef _GetRect = Int32 Function(IntPtr, Pointer<_Rect>);
typedef _GetRectDart = int Function(int, Pointer<_Rect>);
typedef _SetPos = Int32 Function(
  IntPtr,
  IntPtr,
  Int32,
  Int32,
  Int32,
  Int32,
  Uint32,
);
typedef _SetPosDart = int Function(int, int, int, int, int, int, int);
typedef _MonitorFrom = IntPtr Function(IntPtr, Uint32);
typedef _MonitorFromDart = int Function(int, int);
typedef _MonitorInfoFn = Int32 Function(IntPtr, Pointer<_MonitorInfo>);
typedef _MonitorInfoDart = int Function(int, Pointer<_MonitorInfo>);

/// Borderless fullscreen via Win32 directly.
///
/// Deliberately not using `window_manager`: its legacy `setFullScreen` blocked
/// the UI thread (APPLICATION_HANG, no dump, `cnativeapi.dll` loaded) when
/// leaving fullscreen. These calls are synchronous and return immediately.
class FullscreenController {
  static final DynamicLibrary _user32 = DynamicLibrary.open('user32.dll');

  static final _getActiveWindow = _user32.lookupFunction<_IntPtr0, _Int0>(
    'GetActiveWindow',
  );
  static final _getForegroundWindow = _user32.lookupFunction<_IntPtr0, _Int0>(
    'GetForegroundWindow',
  );
  static final _getWindowLong = _user32
      .lookupFunction<_GetLongPtr, _GetLongPtrDart>('GetWindowLongPtrW');
  static final _setWindowLong = _user32
      .lookupFunction<_SetLongPtr, _SetLongPtrDart>('SetWindowLongPtrW');
  static final _getWindowRect = _user32.lookupFunction<_GetRect, _GetRectDart>(
    'GetWindowRect',
  );
  static final _setWindowPos = _user32.lookupFunction<_SetPos, _SetPosDart>(
    'SetWindowPos',
  );
  static final _monitorFromWindow = _user32
      .lookupFunction<_MonitorFrom, _MonitorFromDart>('MonitorFromWindow');
  static final _getMonitorInfo = _user32
      .lookupFunction<_MonitorInfoFn, _MonitorInfoDart>('GetMonitorInfoW');

  static const int _gwlStyle = -16;
  static const int _wsOverlappedWindow = 0x00CF0000;
  static const int _wsPopup = 0x80000000;
  static const int _wsVisible = 0x10000000;
  static const int _swpFrameChanged = 0x0020;
  static const int _swpShowWindow = 0x0040;
  static const int _monitorDefaultToNearest = 2;

  int _handle = 0;
  int _savedStyle = 0;
  int _savedLeft = 0;
  int _savedTop = 0;
  int _savedWidth = 0;
  int _savedHeight = 0;
  bool _fullscreen = false;

  bool get isFullscreen => _fullscreen;

  String? get unsupportedReason => (!Platform.isWindows)
      ? 'Fullscreen toggle is Windows-only in this build.'
      : null;

  int _window() {
    final active = _getActiveWindow();
    return active != 0 ? active : _getForegroundWindow();
  }

  bool enter() {
    if (!Platform.isWindows || _fullscreen) return false;
    final hwnd = _window();
    if (hwnd == 0) return false;

    final rect = calloc<_Rect>();
    final info = calloc<_MonitorInfo>();
    try {
      if (_getWindowRect(hwnd, rect) == 0) return false;
      _savedLeft = rect.ref.left;
      _savedTop = rect.ref.top;
      _savedWidth = rect.ref.right - rect.ref.left;
      _savedHeight = rect.ref.bottom - rect.ref.top;

      final monitor = _monitorFromWindow(hwnd, _monitorDefaultToNearest);
      if (monitor == 0) return false;
      info.ref.cbSize = sizeOf<_MonitorInfo>();
      if (_getMonitorInfo(monitor, info) == 0) return false;

      final bounds = info.ref.rcMonitor;
      final width = bounds.right - bounds.left;
      final height = bounds.bottom - bounds.top;

      _handle = hwnd;
      _savedStyle = _getWindowLong(hwnd, _gwlStyle) & 0xFFFFFFFF;

      final style =
          ((_savedStyle & ~_wsOverlappedWindow) | _wsPopup | _wsVisible) &
          0xFFFFFFFF;
      _setWindowLong(hwnd, _gwlStyle, style);
      _setWindowPos(
        hwnd,
        0,
        bounds.left,
        bounds.top,
        width,
        height,
        _swpFrameChanged | _swpShowWindow,
      );
      _fullscreen = true;
      return true;
    } finally {
      calloc.free(rect);
      calloc.free(info);
    }
  }

  bool exit() {
    if (!Platform.isWindows || !_fullscreen) return false;
    final hwnd = _handle != 0 ? _handle : _window();
    if (hwnd == 0) {
      _fullscreen = false;
      return false;
    }

    _setWindowLong(hwnd, _gwlStyle, _savedStyle);
    _setWindowPos(
      hwnd,
      0,
      _savedLeft,
      _savedTop,
      _savedWidth,
      _savedHeight,
      _swpFrameChanged | _swpShowWindow,
    );
    _fullscreen = false;
    return true;
  }
}
