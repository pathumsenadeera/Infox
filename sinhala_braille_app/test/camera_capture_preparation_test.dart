import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sinhala_braille_app/services/camera_capture_preparation.dart';

const back = CameraDescription(
  name: 'back',
  lensDirection: CameraLensDirection.back,
  sensorOrientation: 90,
);
const front = CameraDescription(
  name: 'front',
  lensDirection: CameraLensDirection.front,
  sensorOrientation: 90,
);

class RecordingCamera extends CameraController {
  RecordingCamera({bool regions = true})
    : super(back, ResolutionPreset.max, enableAudio: false) {
    value = value.copyWith(
      isInitialized: true,
      focusPointSupported: regions,
      exposurePointSupported: regions,
    );
  }
  final calls = <String>[];
  bool failFocus = false;
  bool failRegions = false;

  @override
  Future<void> setFocusMode(FocusMode mode) async {
    calls.add('focus:$mode');
    if (failFocus) throw CameraException('focusFailed', 'test');
    value = value.copyWith(focusMode: mode);
  }

  @override
  Future<void> setExposureMode(ExposureMode mode) async {
    calls.add('exposure:$mode');
  }

  @override
  Future<void> setFocusPoint(Offset? point) async {
    calls.add('focusPoint:$point');
    if (failRegions) throw CameraException('unsupported', 'test');
  }

  @override
  Future<void> setExposurePoint(Offset? point) async {
    calls.add('exposurePoint:$point');
    if (failRegions) throw CameraException('unsupported', 'test');
  }
}

void main() {
  test('prefers rear camera even when front is listed first', () {
    expect(selectCaptureCamera([front, back]), back);
    expect(selectCaptureCamera([front]), front);
  });
  test('sets auto modes and centre metering without locking focus', () async {
    final camera = RecordingCamera();
    await prepareCameraForCapture(camera);
    expect(camera.calls, [
      'focus:FocusMode.auto',
      'exposure:ExposureMode.auto',
      'focusPoint:Offset(0.5, 0.5)',
      'exposurePoint:Offset(0.5, 0.5)',
    ]);
    expect(camera.value.focusMode, FocusMode.auto);
  });
  test('unsupported metering does not prevent automatic focus', () async {
    final camera = RecordingCamera(regions: false);
    await prepareCameraForCapture(camera);
    expect(camera.calls.length, 2);
    final rejectsRegions = RecordingCamera()..failRegions = true;
    await prepareCameraForCapture(rejectsRegions);
    expect(rejectsRegions.value.focusMode, FocusMode.auto);
  });
  test(
    'focus setup error is propagated instead of starting a capture',
    () async {
      final camera = RecordingCamera()..failFocus = true;
      await expectLater(
        prepareCameraForCapture(camera),
        throwsA(isA<CameraException>()),
      );
      expect(camera.calls.length, 1);
    },
  );
  test('raw movement and tilt invalidate otherwise flat guidance', () {
    final stability = CaptureStability();
    expect(stability.update(0, 0, 9.8, Duration.zero), isFalse);
    expect(
      stability.update(0.1, 0, 9.8, const Duration(milliseconds: 100)),
      isTrue,
    );
    expect(
      stability.update(1.1, 0, 9.8, const Duration(milliseconds: 200)),
      isFalse,
    );
    expect(
      stability.isFreshAndSteady(const Duration(milliseconds: 200)),
      isFalse,
    );
    expect(
      stability.update(2, 0, 9.8, const Duration(milliseconds: 300)),
      isFalse,
    );
    expect(
      stability.update(0, 0, 12, const Duration(milliseconds: 400)),
      isFalse,
    );
  });
  test('stale sensors and resume reset cannot qualify for capture', () {
    final stability = CaptureStability();
    stability.update(0, 0, 9.8, Duration.zero);
    stability.update(0, 0, 9.8, const Duration(milliseconds: 100));
    expect(
      stability.isFreshAndSteady(const Duration(milliseconds: 500)),
      isTrue,
    );
    expect(
      stability.isFreshAndSteady(const Duration(milliseconds: 601)),
      isFalse,
    );
    stability.reset();
    expect(
      stability.isFreshAndSteady(const Duration(milliseconds: 700)),
      isFalse,
    );
    expect(
      stability.update(0, 0, 9.8, const Duration(milliseconds: 800)),
      isFalse,
    );
  });
}
