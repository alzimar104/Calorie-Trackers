import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeScannerView extends StatefulWidget {
  final Function(String) onBarcodeDetected;
  final VoidCallback onClose;

  const BarcodeScannerView({
    Key? key,
    required this.onBarcodeDetected,
    required this.onClose,
  }) : super(key: key);

  @override
  State<BarcodeScannerView> createState() => _BarcodeScannerViewState();
}

class _BarcodeScannerViewState extends State<BarcodeScannerView> {
  MobileScannerController controller = MobileScannerController();
  bool _isScanning = true;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Barcode scanner view
        MobileScanner(
          controller: controller,
          onDetect: (capture) {
            final List<Barcode> barcodes = capture.barcodes;
            if (barcodes.isNotEmpty && _isScanning) {
              // Get the first detected barcode
              final String? code = barcodes.first.rawValue;
              if (code != null && code.isNotEmpty) {
                // Stop scanning to prevent multiple detections
                setState(() {
                  _isScanning = false;
                });
                
                // Call the callback with the detected barcode
                widget.onBarcodeDetected(code);
              }
            }
          },
        ),
        
        // Overlay with instructions and close button
        SafeArea(
          child: Column(
            children: [
              // Top bar with close button
              Container(
                color: Colors.black54,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Barkodu tarayın',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.white),
                      onPressed: widget.onClose,
                    ),
                  ],
                ),
              ),
              
              // Scanning area indicator
              Expanded(
                child: Center(
                  child: Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.white,
                        width: 2.0,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              
              // Bottom instructions
              Container(
                color: Colors.black54,
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Barkodu çerçeve içine yerleştirin',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
