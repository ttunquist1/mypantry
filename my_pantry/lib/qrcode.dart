import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QRScannerPage extends StatefulWidget {
  const QRScannerPage({super.key});

  @override
  State<QRScannerPage> createState() => _QRScannerPageState();
}

class _QRScannerPageState extends State<QRScannerPage>
    with WidgetsBindingObserver {
  late final MobileScannerController _scannerController;
  StreamSubscription<BarcodeCapture>? _barcodeSubscription;
  bool _didReturnCode = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scannerController = MobileScannerController(autoStart: false);
    _barcodeSubscription = _scannerController.barcodes.listen(_handleDetection);
    unawaited(_scannerController.start());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_barcodeSubscription?.cancel());
    _barcodeSubscription = null;
    unawaited(_scannerController.dispose());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_scannerController.value.hasCameraPermission || _didReturnCode) {
      return;
    }

    switch (state) {
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        return;
      case AppLifecycleState.resumed:
        _barcodeSubscription ??= _scannerController.barcodes.listen(
          _handleDetection,
        );
        unawaited(_scannerController.start());
      case AppLifecycleState.inactive:
        unawaited(_barcodeSubscription?.cancel());
        _barcodeSubscription = null;
        unawaited(_scannerController.stop());
    }
  }

  Future<void> _handleDetection(BarcodeCapture capture) async {
    if (_didReturnCode) {
      return;
    }

    if (capture.barcodes.isEmpty) {
      return;
    }
    final code = capture.barcodes.first.rawValue;
    if (code == null || code.isEmpty) {
      return;
    }

    _didReturnCode = true;
    await _scannerController.stop();

    if (!mounted) {
      return;
    }
    Navigator.pop(context, code);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan QR Code')),
      body: MobileScanner(
        controller: _scannerController,
        onDetect: _handleDetection,
      ),
    );
  }
}
