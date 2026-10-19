import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:sinhala_braille_app/main.dart';
import 'package:sinhala_braille_app/screen/assistive_reader_screen.dart';
import 'package:sinhala_braille_app/screen/audio_player_screen.dart';
import 'package:sinhala_braille_app/providers/tts_service.dart';
import 'package:sinhala_braille_app/providers/user_provider.dart';
import 'package:sinhala_braille_app/services/scan_service.dart';
import 'package:sinhala_braille_app/services/camera_capture_preparation.dart';

class LiveCameraScreen extends StatefulWidget {
  const LiveCameraScreen({
    super.key,
    this.cameraFactory,
    this.accelerometerEvents,
  });
  final CameraController Function(CameraDescription)? cameraFactory;
  final Stream<AccelerometerEvent>? accelerometerEvents;

  @override
  State<LiveCameraScreen> createState() => _LiveCameraScreenState();
}

class _LiveCameraScreenState extends State<LiveCameraScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  String? _cameraError;
  bool _appActive = true;
  bool _cancelled = false;
  bool _preparingFocus = false;
  int _cameraEpoch = 0;
  int _holdEpoch = 0;
  Future<void> _cameraDisposal = Future.value();
  final _stability = CaptureStability();
  final _sensorClock = Stopwatch()..start();

  /// Warm-up gives the camera time to settle; it does not measure sharpness.
  bool _cameraWarmUpDone = false;

  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;

  // ── Guidance state ───────────────────────────────────────────────────────
  String _guidanceMessage = 'INITIALIZING...';
  bool _isAligned = false;
  Color _guidanceColor = Colors.white;

  /// Tracks the last spoken TTS instruction so we only announce when the
  /// message changes — avoids audio spam on every accelerometer event (FR 14).
  String _lastSpokenMessage = '';

  // Hold-window timer & countdown
  // 3 s hold window — gives enough time to confirm the device is truly stable.
  static const _holdDuration = Duration(milliseconds: 3000);
  Timer? _captureTimer;
  double _holdProgress = 0.0;
  Timer? _progressTimer;
  bool _isCapturing = false;
  bool _isUploading = false;
  String _uploadStatus = '';

  /// True for 6 s after a capture/upload error to prevent the accelerometer
  /// from immediately re-triggering alignment and causing a capture loop.
  bool _errorCooldown = false;

  // ── EMA (Exponential Moving Average) – simulated Kalman smoothing ────────
  // Alpha close to 1 = fast response; close to 0 = heavy smoothing.
  // 0.12 gives slightly more smoothing to filter micro-jitter.
  static const double _alpha = 0.12;
  double _smoothX = 0;
  double _smoothY = 0;
  double _smoothZ = 9.8;

  // ── Alignment thresholds ─────────────────────────────────────────────────
  static const double _zMin =
      8.8; // device must be mostly face-up/flat (tighter)
  static const double _xyMax = 1.5; // max lateral tilt allowed (tighter)

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCameraAndSensors();
  }

  /// Release the camera in the background and restart warm-up on return.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _appActive = true;
      _initializeCameraAndSensors();
    } else {
      _appActive = false;
      _cancelHoldWindow();
      _stability.reset();
      _cameraWarmUpDone = false;
      _isAligned = false;
      _holdProgress = 0;
      _isCameraInitialized = false;
      _releaseCamera();
      if (mounted) setState(() {});
    }
  }

  void _releaseCamera() {
    ++_cameraEpoch;
    _isCameraInitialized = false;
    _cameraWarmUpDone = false;
    final camera = _cameraController;
    _cameraController = null;
    if (camera != null) {
      _cameraDisposal = camera.dispose().catchError((Object error) {
        debugPrint('Camera disposal error: $error');
      });
    }
  }

  Future<void> _enableTorch() async {
    try {
      if (_cameraController != null && _cameraController!.value.isInitialized) {
        await _cameraController!.setFlashMode(FlashMode.torch);
      }
    } catch (e) {
      debugPrint('Torch error: $e');
    }
  }

  Future<void> _initializeCameraAndSensors() async {
    await _cameraDisposal;
    if (!mounted || !_appActive || _cancelled || _cameraController != null) {
      return;
    }
    final epoch = _cameraEpoch;
    setState(() => _cameraError = null);
    if (cameras.isNotEmpty) {
      final camera =
          widget.cameraFactory?.call(selectCaptureCamera(cameras)) ??
          CameraController(
            selectCaptureCamera(cameras),
            ResolutionPreset
                .max, // Maximum sensor resolution for best backend quality
            enableAudio: false,
            imageFormatGroup: ImageFormatGroup.jpeg,
          );
      _cameraController = camera;
      try {
        await camera.initialize();
        if (!mounted || !_appActive || epoch != _cameraEpoch || _cancelled) {
          return;
        }
        // Brief pause so the sensor pipeline (torch, AE, AF, AWB) can start.
        await Future.delayed(const Duration(milliseconds: 500));
        if (!mounted || !_appActive || epoch != _cameraEpoch || _cancelled) {
          return;
        }
        await _enableTorch();
        await prepareCameraForCapture(camera);
        if (!mounted || !_appActive || epoch != _cameraEpoch || _cancelled) {
          return;
        }
        if (mounted) setState(() => _isCameraInitialized = true);

        // ── Warm-up guard ────────────────────────────────────────────────
        // Block capture for 2 seconds after init so that auto-exposure,
        // auto-focus, and auto-white-balance have time to fully settle.
        // The guidance message will show 'STABILIZING...' during this window.
        await Future.delayed(const Duration(milliseconds: 2000));
        if (mounted && _appActive && epoch == _cameraEpoch && !_cancelled) {
          setState(() {
            _cameraWarmUpDone = true;
            _guidanceMessage = 'HOLD DEVICE STEADY';
          });
        }
        // ─────────────────────────────────────────────────────────────────
      } catch (e) {
        if (!mounted || !_appActive || epoch != _cameraEpoch || _cancelled) {
          return;
        }
        debugPrint('Camera init error: $e');
        _releaseCamera();
        setState(
          () => _cameraError = 'CAMERA UNAVAILABLE.\nGO BACK AND TRY AGAIN.',
        );
        TtsService.instance.announceError(
          'Failed to initialize camera. Please check camera permissions.',
          errorCode: 'ERR_CAM_INIT',
        );
      }
    } else {
      setState(() => _cameraError = 'NO CAMERA AVAILABLE');
    }

    if (!mounted || !_appActive || epoch != _cameraEpoch || _cancelled) return;
    // Listen to raw accelerometer and apply EMA smoothing
    _accelerometerSubscription ??= (widget.accelerometerEvents ??
            accelerometerEventStream())
        .listen((AccelerometerEvent event) {
          if (!mounted || !_appActive || _cancelled || _isCapturing) return;
          _stability.update(event.x, event.y, event.z, _sensorClock.elapsed);

          // Apply EMA filter on each axis
          _smoothX = _alpha * event.x + (1 - _alpha) * _smoothX;
          _smoothY = _alpha * event.y + (1 - _alpha) * _smoothY;
          _smoothZ = _alpha * event.z.abs() + (1 - _alpha) * _smoothZ;

          _updateGuidance(_smoothX, _smoothY, _smoothZ);
        });
  }

  /// Evaluate smoothed sensor data, update guidance message and trigger capture.
  void _updateGuidance(double x, double y, double z) {
    if (!mounted) return;

    // If camera is still warming up, show a stabilising message and skip logic.
    if (!_cameraWarmUpDone) {
      setState(() {
        _guidanceMessage = 'STABILIZING CAMERA...';
        _guidanceColor = Colors.white54;
      });
      return;
    }

    final bool zOk = z >= _zMin;
    final bool xyOk = x.abs() < _xyMax && y.abs() < _xyMax;
    final bool aligned =
        zOk && xyOk && _stability.isFreshAndSteady(_sensorClock.elapsed);

    String message;
    Color color;

    if (!zOk) {
      // Device is not face-up enough
      message = 'HOLD DEVICE FLAT';
      color = Colors.redAccent;
    } else if (x > _xyMax) {
      message = 'TILT PHONE LEFT';
      color = Colors.orangeAccent;
    } else if (x < -_xyMax) {
      message = 'TILT PHONE RIGHT';
      color = Colors.orangeAccent;
    } else if (y > _xyMax) {
      message = 'TILT PHONE BACK';
      color = Colors.orangeAccent;
    } else if (y < -_xyMax) {
      message = 'TILT PHONE FORWARD';
      color = Colors.orangeAccent;
    } else if (!aligned) {
      message = 'HOLD DEVICE STEADY';
      color = Colors.orangeAccent;
    } else {
      // Aligned!
      message = 'DEVICE ALIGNED – HOLD STEADY...';
      color = Colors.greenAccent;
    }

    setState(() {
      _guidanceMessage = message;
      _guidanceColor = color;
    });

    // ── FR 14: Announce via TTS only when the message changes ───────────────
    // This prevents audio spam on every sensor event while still giving
    // clear, timely verbal guidance whenever the direction changes.
    if (message != _lastSpokenMessage) {
      _lastSpokenMessage = message;
      TtsService.instance.speakEnglish(message);
    }
    // ─────────────────────────────────────────────────────────────────────────

    if (aligned &&
        !_isAligned &&
        !_isCapturing &&
        !_errorCooldown &&
        !_preparingFocus) {
      setState(() => _isAligned = true);
      _startHoldWindow();
    } else if (!aligned && _isAligned) {
      setState(() {
        _isAligned = false;
        _holdProgress = 0.0;
      });
      _cancelHoldWindow();
    }
  }

  // ── Hold window & countdown ──────────────────────────────────────────────

  Future<void> _startHoldWindow() async {
    _cancelHoldWindow();
    final epoch = _holdEpoch;
    final camera = _cameraController;
    if (camera == null || !camera.value.isInitialized) return;
    _preparingFocus = true;
    try {
      await prepareCameraForCapture(camera);
    } catch (error) {
      if (mounted && epoch == _holdEpoch && !_cancelled) {
        setState(() {
          _isAligned = false;
          _errorCooldown = true;
        });
        TtsService.instance.announceError(
          'Unable to prepare camera focus. Please try again.',
          errorCode: 'ERR_CAM_FOCUS',
        );
        Future.delayed(const Duration(seconds: 6), () {
          if (mounted) setState(() => _errorCooldown = false);
        });
      }
      return;
    } finally {
      _preparingFocus = false;
    }
    if (!mounted ||
        !_appActive ||
        _cancelled ||
        epoch != _holdEpoch ||
        !_isAligned) {
      return;
    }
    final start = _sensorClock.elapsed;

    // Smooth progress animation timer (fires every ~30 ms)
    _progressTimer = Timer.periodic(const Duration(milliseconds: 30), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      final elapsed = (_sensorClock.elapsed - start).inMilliseconds;
      final progress = (elapsed / _holdDuration.inMilliseconds).clamp(0.0, 1.0);
      setState(() => _holdProgress = progress);
    });

    _captureTimer = Timer(_holdDuration, _captureAndSave);
  }

  void _cancelHoldWindow() {
    ++_holdEpoch;
    _captureTimer?.cancel();
    _progressTimer?.cancel();
    _captureTimer = null;
    _progressTimer = null;
  }

  Future<void> _captureAndSave() async {
    final camera = _cameraController;
    if (!mounted || _isCapturing || !_appActive || _cancelled) return;
    _cancelHoldWindow();
    if (!_isAligned ||
        !_cameraWarmUpDone ||
        camera == null ||
        !camera.value.isInitialized ||
        camera.value.isPreviewPaused ||
        camera.value.isTakingPicture ||
        camera.value.focusMode != FocusMode.auto ||
        !_stability.isFreshAndSteady(_sensorClock.elapsed)) {
      setState(() {
        _isAligned = false;
        _holdProgress = 0;
      });
      return;
    }
    final epoch = _cameraEpoch;
    File? temporaryPhoto;
    setState(() => _isCapturing = true);

    try {
      // Take the full-resolution JPEG photo
      final XFile photo = await camera.takePicture();
      temporaryPhoto = File(photo.path);
      if (!mounted || _cancelled || !_appActive || epoch != _cameraEpoch) {
        if (mounted) setState(() => _isCapturing = false);
        return;
      }
      // Pause preview to give user feedback that capture is complete
      await _cameraController?.pausePreview();
      debugPrint('Photo captured: ${photo.path}');

      // Camera output is temporary; retain it only while uploading.
      final savePath = photo.path;
      if (!mounted || _cancelled || !_appActive || epoch != _cameraEpoch) {
        if (mounted) setState(() => _isCapturing = false);
        return;
      }
      // ── FR 17: Upload Braille scan to backend for AI translation ─────────
      setState(() {
        _isUploading = true;
        _uploadStatus = 'uploading';
      });
      await TtsService.instance.speakEnglish(
        'Photo captured. Uploading and translating Braille image.',
      );

      if (!mounted || _cancelled) return;

      final user = UserProvider.of(context);
      final userId = int.tryParse(user.userId ?? '0') ?? 0;

      final result = await ScanService.uploadBrailleImage(
        imageFile: File(savePath),
        isCancelled: () => _cancelled || !mounted,
        userId: userId,
        onStatusUpdate: (status) {
          if (mounted && !_cancelled) {
            setState(() {
              _uploadStatus = status;
            });
          }
        },
      );

      if (!mounted || _cancelled) return;

      await TtsService.instance.speakEnglish('Translation complete.');

      if (!mounted || _cancelled) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder:
              (_) => AudioPlayerScreen(
                translatedText: result.translatedText,
                documentId:
                    result.docId == null ? null : 'scan_${result.docId}',
                documentTitle:
                    'Scan ${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}',
              ),
        ),
      );
      return;
    } catch (e) {
      debugPrint('Capture or upload error: $e');
      try {
        await _cameraController?.resumePreview();
      } catch (_) {}

      if (mounted && !_cancelled) {
        final wasUploading = _isUploading;
        // Reset ALL capture-related state so the hold-window can restart cleanly.
        setState(() {
          _isCapturing = false;
          _isUploading = false;
          _uploadStatus = '';
          _isAligned = false;
          _holdProgress = 0.0;
          // Block new captures for 6 s so the accelerometer can't immediately
          // re-trigger alignment and cause a capture → fail → capture loop.
          _errorCooldown = true;
        });
        _cancelHoldWindow();

        // Clear the cooldown after 6 s (async, safe if widget is disposed).
        Future.delayed(const Duration(seconds: 6), () {
          if (mounted) setState(() => _errorCooldown = false);
        });

        // Capture context-dependent objects NOW, before the await below.
        // SnackBarAction.onPressed fires asynchronously (when user taps the
        // button), so `context` may be stale/unmounted by then, causing the
        // "widget has been unmounted" crash seen in the logs.
        final scaffoldMessenger = ScaffoldMessenger.of(context);
        final navigator = Navigator.of(context);

        await TtsService.instance.announceError(
          wasUploading
              ? 'Translation upload failed. Please check your network connection.'
              : 'Image capture failed. Please hold device steady and try again.',
          errorCode: wasUploading ? 'ERR_UPLOAD' : 'ERR_CAPTURE',
        );

        // Dismiss any snackbar that is already visible/queued before showing
        // the new error — prevents stale messages getting stuck on screen.
        scaffoldMessenger.clearSnackBars();
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              'Processing failed: ${e.toString().replaceAll("Exception: ", "")}',
            ),
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: 'Offline View',
              textColor: Colors.greenAccent,
              onPressed: () {
                navigator.pushReplacement(
                  MaterialPageRoute(builder: (_) => const AudioPlayerScreen()),
                );
              },
            ),
          ),
        );
      }
    } finally {
      try {
        if (temporaryPhoto != null && await temporaryPhoto.exists()) {
          await temporaryPhoto.delete();
        }
      } catch (error) {
        debugPrint('Temporary scan cleanup failed: $error');
      }
    }
  }

  /// Aborts active scan, clears buffers, announces "Scan cancelled" and redirects to Home (FR 32).
  Future<void> _onCancelScan() async {
    if (_cancelled) return;
    _cancelled = true;
    _cancelHoldWindow();
    _releaseCamera();
    // Wrap all state mutations in setState so the UI reflects the cancellation
    // immediately (previously these were bare assignments with no rebuild).
    if (mounted) {
      setState(() {
        _isCapturing = false;
        _isUploading = false;
        _uploadStatus = '';
        _holdProgress = 0.0;
        _isAligned = false;
      });
    }
    await TtsService.instance.speakEnglish('Scan cancelled');
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AssistiveReaderScreen()),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _accelerometerSubscription?.cancel();
    _cancelHoldWindow();
    _cancelled = true;
    _releaseCamera();
    super.dispose();
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _onCancelScan();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0B0914),
        body: SafeArea(
          child: Column(
            children: [
              // Purple header
              Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Color(0xFF7B4FE0),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(40),
                    bottomRight: Radius.circular(40),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 30),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _onCancelScan,
                      icon: const Icon(
                        Icons.arrow_back_sharp,
                        size: 30,
                        color: Colors.black,
                      ),
                      style: ButtonStyle(
                        backgroundColor: WidgetStateProperty.all(
                          Colors.grey.shade300,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'LIVE\nCAMERA FEED',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Camera preview with guidance overlay
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFFB8B8B8),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child:
                        _isCameraInitialized
                            ? Stack(
                              fit: StackFit.expand,
                              children: [
                                CameraPreview(_cameraController!),

                                // Remove darkened overlay when aligned so braille is visible
                                if (!_isAligned)
                                  Container(color: Colors.black38),

                                // Guidance text
                                Align(
                                  alignment: Alignment.center,
                                  child: Text(
                                    _guidanceMessage,
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.poppins(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: _guidanceColor,
                                      shadows: [
                                        const Shadow(
                                          blurRadius: 8,
                                          color: Colors.black87,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                // Countdown arc — only visible while holding steady
                                if (_isAligned)
                                  Positioned(
                                    bottom: 24,
                                    left: 0,
                                    right: 0,
                                    child: Center(
                                      child: SizedBox(
                                        width: 72,
                                        height: 72,
                                        child: _HoldProgressRing(
                                          progress: _holdProgress,
                                        ),
                                      ),
                                    ),
                                  ),

                                // Capturing spinner overlay
                                if (_isCapturing)
                                  Container(
                                    color: Colors.black54,
                                    child: Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (_uploadStatus != 'error')
                                            const CircularProgressIndicator(
                                              color: Colors.greenAccent,
                                            ),
                                          const SizedBox(height: 16),
                                          Text(
                                            _isUploading
                                                ? 'STATUS: ${_uploadStatus.toUpperCase()}'
                                                : 'SAVING IMAGE...',
                                            textAlign: TextAlign.center,
                                            style: GoogleFonts.poppins(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            )
                            : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.camera_alt,
                                  size: 60,
                                  color: Colors.grey[700],
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  _cameraError ?? 'INITIALIZING CAMERA...',
                                  style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                  ),
                ),
              ),

              // Bottom status bar
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                child: Container(
                  width: double.infinity,
                  height: 80,
                  decoration: BoxDecoration(
                    color:
                        _isAligned
                            ? const Color(0xFF2E7D32)
                            : const Color(0xFF7B4FE0),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _isCapturing
                        ? (_isUploading
                            ? 'STATUS: ${_uploadStatus.toUpperCase()}'
                            : 'CAPTURING IMAGE...')
                        : _isAligned
                        ? 'AUTO-CAPTURE IN PROGRESS'
                        : 'AUTO-CAPTURE IS ACTIVE',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Countdown ring widget ─────────────────────────────────────────────────

class _HoldProgressRing extends StatelessWidget {
  final double progress; // 0.0 → 1.0

  const _HoldProgressRing({required this.progress});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _RingPainter(progress: progress),
      child: Center(
        child: Text(
          '${((1 - progress) * 3.0).toStringAsFixed(1)}s',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;

  const _RingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 4;

    // Background ring
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white24
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5,
    );

    // Progress arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2, // start from top
      2 * pi * progress,
      false,
      Paint()
        ..color = Colors.greenAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}
