import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Camera view for scanning a Fuata pack QR (issue #34).
///
/// Pops with the first barcode's raw value. Runs entirely on-device via
/// ML Kit's on-device model (bundled with the plugin, no network). The
/// camera permission is requested by the plugin when this screen opens,
/// which is the only moment the person has asked for the camera.
class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );
  bool _handled = false;

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw != null && raw.isNotEmpty) {
        _handled = true;
        Navigator.of(context).pop(raw);
        return;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan a pack')),
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          // A simple frame, so the person knows what to point at. The
          // scanner works regardless of where in the viewfinder the code
          // is — the frame is a hint, not a mask.
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 32,
            child: Text(
              'Point the camera at a Fuata pack QR',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}