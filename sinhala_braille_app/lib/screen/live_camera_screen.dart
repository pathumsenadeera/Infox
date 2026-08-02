import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sinhala_braille_app/main.dart';
import 'package:sinhala_braille_app/screen/assistive_reader_screen.dart';
import 'package:sinhala_braille_app/screen/audio_player_screen.dart';
// TODO: Uncomment when backend /scan endpoint is ready
// import 'package:sinhala_braille_app/services/scan_service.dart';

class LiveCameraScreen extends StatefulWidget {
  const LiveCameraScreen({super.key});

  @override
  State<LiveCameraScreen> createState() => _LiveCameraScreenState();
}

class _LiveCameraScreenState extends State<LiveCameraScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  CameraController? _cameraController;
  bool _isCameraInitialized = false;

  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;

  // ── Guidance state ───────────────────────────────────────────────────────
  String _guidanceMessage = 'HOLD DEVICE STEADY';
  bool _isAligned = false;
  Color _guidanceColor = Colors.white;

  // Hold-window timer & countdown
  static const _holdDuration = Duration(milliseconds: 1500);
  Timer? _captureTimer;
  double _holdProgress = 0.0;
  Timer? _progressTimer;
  bool _isCapturing = false;

  // ── EMA (Exponential Moving Average) – simulated Kalman smoothing ────────
  // Alpha close to 1 = fast response; close to 0 = heavy smoothing.
  static const double _alpha = 0.15;
  double _smoothX = 0;
  double _smoothY = 0;
  double _smoothZ = 9.8;

  // ── Alignment thresholds ─────────────────────────────────────────────────
  static const double _zMin = 8.5;   // device must be mostly face-up/flat
  static const double _xyMax = 1.8;  // max lateral tilt allowed

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCameraAndSensors();
  }

  /// Re-apply torch when the app comes back to the foreground
  /// (e.g. after the user switches apps or returns from AudioPlayerScreen).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _enableTorch();
    }
  }

  Future<void> _enableTorch() async {
    try {
      if (_cameraController != null &&
          _cameraController!.value.isInitialized) {
        await _cameraController!.setFlashMode(FlashMode.torch);
      }
    } catch (e) {
      debugPrint('Torch error: $e');
    }
  }

  Future<void> _initializeCameraAndSensors() async {
    if (cameras.isNotEmpty) {
      _cameraController = CameraController(
        cameras[0],
        ResolutionPreset.max,   // Maximum sensor resolution for best backend quality
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      try {
        await _cameraController!.initialize();
        // Small delay ensures the hardware is fully ready before enabling torch
        await Future.delayed(const Duration(milliseconds: 300));
        await _enableTorch();
        if (mounted) setState(() => _isCameraInitialized = true);
      } catch (e) {
        debugPrint('Camera init error: $e');
      }
    }

    // Listen to raw accelerometer and apply EMA smoothing
    _accelerometerSubscription =
        accelerometerEventStream().listen((AccelerometerEvent event) {
      if (!mounted) return;

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

    final bool zOk = z >= _zMin;
    final bool xyOk = x.abs() < _xyMax && y.abs() < _xyMax;
    final bool aligned = zOk && xyOk;

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
    } else {
      // Aligned!
      message = 'DEVICE ALIGNED – HOLD STEADY...';
      color = Colors.greenAccent;
    }

    setState(() {
      _guidanceMessage = message;
      _guidanceColor = color;
    });

    if (aligned && !_isAligned) {
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

  void _startHoldWindow() {
    _cancelHoldWindow();
    final start = DateTime.now();

    // Smooth progress animation timer (fires every ~30 ms)
    _progressTimer = Timer.periodic(const Duration(milliseconds: 30), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      final elapsed = DateTime.now().difference(start).inMilliseconds;
      final progress = (elapsed / _holdDuration.inMilliseconds).clamp(0.0, 1.0);
      setState(() => _holdProgress = progress);
    });

    _captureTimer = Timer(_holdDuration, _captureAndSave);
  }

  void _cancelHoldWindow() {
    _captureTimer?.cancel();
    _progressTimer?.cancel();
    _captureTimer = null;
    _progressTimer = null;
  }

  Future<void> _captureAndSave() async {
    if (!mounted || _isCapturing) return;
    setState(() => _isCapturing = true);

    try {
      // Take the full-resolution JPEG photo
      final XFile photo = await _cameraController!.takePicture();
      debugPrint('Photo captured: ${photo.path}');

      // Save to public Downloads folder — visible in Files app immediately
      Directory scansDir = Directory('/storage/emulated/0/Download/BrailleScans');
      try {
        if (!await scansDir.exists()) await scansDir.create(recursive: true);
      } catch (_) {
        // Fallback to app-specific external dir on permission failure
        final externalDir = await getExternalStorageDirectory();
        scansDir = Directory('${externalDir!.path}/BrailleScans');
        if (!await scansDir.exists()) await scansDir.create(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final savePath = '${scansDir.path}/braille_scan_$timestamp.jpg';

      // Direct copy — zero quality loss, no decode/re-encode
      await File(photo.path).copy(savePath);
      debugPrint('Saved: $savePath');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image saved to Downloads/BrailleScans')),
      );

      // ── TODO: Backend upload ─────────────────────────────────────────────
      // When the backend /scan endpoint is ready:
      //
      // 1. Uncomment the scan_service.dart import at the top of this file.
      // 2. Uncomment the block below.
      //
      // final user = UserProvider.of(context);
      // final result = await ScanService.uploadBrailleImage(
      //   imageFile: File(savePath),
      //   userId: int.parse(user.userId ?? '0'),
      // );
      // if (!mounted) return;
      // Navigator.pushReplacement(context, MaterialPageRoute(
      //   builder: (_) => AudioPlayerScreen(translatedText: result.translatedText),
      // ));
      // return;
      // ─────────────────────────────────────────────────────────────────────────

      // Temporary: navigate without translated text until backend is live
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AudioPlayerScreen()),
        );
      }
    } catch (e) {
      debugPrint('Capture error: $e');
      if (mounted) {
        setState(() {
          _isCapturing = false;
          _isAligned = false;
          _holdProgress = 0.0;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Capture failed: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _accelerometerSubscription?.cancel();
    _cancelHoldWindow();
    _cameraController?.dispose();
    super.dispose();
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AssistiveReaderScreen(),
                        ),
                      );
                    },
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
                  child: _isCameraInitialized
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
                                      const CircularProgressIndicator(
                                          color: Colors.greenAccent),
                                      const SizedBox(height: 16),
                                      Text(
                                        'SAVING...',
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
                            Icon(Icons.camera_alt,
                                size: 60, color: Colors.grey[700]),
                            const SizedBox(height: 14),
                            Text(
                              'INITIALIZING CAMERA...',
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
                  color: _isAligned
                      ? const Color(0xFF2E7D32)
                      : const Color(0xFF7B4FE0),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Text(
                  _isCapturing
                      ? 'CAPTURING IMAGE...'
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
          '${((1 - progress) * 1.5).toStringAsFixed(1)}s',
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
