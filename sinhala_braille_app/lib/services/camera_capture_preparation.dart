import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

/// Configure continuous autofocus without prematurely locking the lens.
/// Acknowledged settings are not proof that the image is sharp.
Future<void> prepareCameraForCapture(CameraController camera) async {
  await camera.setFocusMode(FocusMode.auto);
  await camera.setExposureMode(ExposureMode.auto);
  if (camera.value.focusPointSupported) {
    try {
      await camera.setFocusPoint(const Offset(0.5, 0.5));
    } on CameraException {
      // Some devices advertise metering regions but reject them. Keep auto AF.
    }
  }
  if (camera.value.exposurePointSupported) {
    try {
      await camera.setExposurePoint(const Offset(0.5, 0.5));
    } on CameraException {
      // Device-selected exposure remains available without a metering region.
    }
  }
}

CameraDescription selectCaptureCamera(List<CameraDescription> cameras) {
  return cameras.firstWhere(
    (camera) => camera.lensDirection == CameraLensDirection.back,
    orElse: () => cameras.first,
  );
}

/// Raw acceleration catches movement that the guidance smoothing can hide.
class CaptureStability {
  List<double>? _previous;
  Duration? _lastSample;
  bool _steady = false;

  bool update(double x, double y, double z, Duration elapsed) {
    final previous = _previous;
    _previous = [x, y, z];
    _lastSample = elapsed;
    final jump =
        previous == null ||
        (x - previous[0]).abs() > 0.8 ||
        (y - previous[1]).abs() > 0.8 ||
        (z - previous[2]).abs() > 0.8;
    _steady =
        !jump &&
        x.abs() < 1.5 &&
        y.abs() < 1.5 &&
        z.abs() >= 8.8 &&
        z.abs() <= 10.8;
    return _steady;
  }

  bool isFreshAndSteady(Duration elapsed) =>
      _steady &&
      _lastSample != null &&
      elapsed - _lastSample! <= const Duration(milliseconds: 500);

  void reset() {
    _previous = null;
    _lastSample = null;
    _steady = false;
  }
}
