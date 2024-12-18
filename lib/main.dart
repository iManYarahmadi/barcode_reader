import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  runApp(MyApp(cameras: cameras));
}

class MyApp extends StatelessWidget {
  final List<CameraDescription> cameras;

  const MyApp({Key? key, required this.cameras}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: BarcodeScannerScreen(cameras: cameras),
    );
  }
}

class BarcodeScannerScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const BarcodeScannerScreen({Key? key, required this.cameras}) : super(key: key);

  @override
  _BarcodeScannerScreenState createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  late CameraController _cameraController;
  late BarcodeScanner _barcodeScanner;
  bool isProcessing = false;
  int frameCount = 0;

  @override
  void initState() {
    super.initState();
    _barcodeScanner = GoogleMlKit.vision.barcodeScanner();
    _requestCameraPermission();
  }

  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      _initializeCamera();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Camera permission is required')),
      );
    }
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      debugPrint("No cameras available.");
      return;
    }

    _cameraController = CameraController(
      cameras[0],
      ResolutionPreset.high,  // Set to high resolution for better quality
      enableAudio: false,
    );

    try {
      await _cameraController.initialize();
      debugPrint("Camera initialized successfully.");
      setState(() {});
      _startImageStream();
    } catch (e) {
      debugPrint("Error initializing camera: $e");
    }
  }

  void _startImageStream() {
    _cameraController.startImageStream((CameraImage image) async {
      if (isProcessing) return;

      frameCount++;
      if (frameCount % 3 != 0) return; // Process every 3rd frame for better performance

      isProcessing = true;

      try {
        final WriteBuffer allBytes = WriteBuffer();
        for (Plane plane in image.planes) {
          allBytes.putUint8List(plane.bytes);
        }
        final bytes = allBytes.done().buffer.asUint8List();

        final inputImage = InputImage.fromBytes(
          bytes: bytes,
          metadata: InputImageMetadata(
            size: Size(image.width.toDouble(), image.height.toDouble()),
            rotation: InputImageRotation.values[widget.cameras[0].sensorOrientation ~/ 90],
            format: InputImageFormat.nv21,
            bytesPerRow: image.planes[0].bytesPerRow,
          ),
        );

        debugPrint("Processing image...");
        final barcodes = await _barcodeScanner.processImage(inputImage);

        if (barcodes.isNotEmpty) {
          debugPrint("Barcode detected: ${barcodes.first.rawValue}");
          _navigateToBarcodeInfo(barcodes.first);
        } else {
          debugPrint("No barcode found.");
        }
      } catch (e) {
        debugPrint("Error processing image: $e");
      } finally {
        isProcessing = false;
      }
    });
  }

  void _navigateToBarcodeInfo(Barcode barcode) {
    _cameraController.stopImageStream(); // Stop stream before navigating

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BarcodeInfoScreen(barcode: barcode),
      ),
    ).then((_) {
      _startImageStream();
    });
  }

  @override
  void dispose() {
    _cameraController.dispose();
    _barcodeScanner.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_cameraController.value.isInitialized) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: Stack(
        children: [


          // Barcode overlay or instructions (you can change this part to suit your needs)
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Scanning for barcodes...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  backgroundColor: Colors.black54,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class BarcodeInfoScreen extends StatelessWidget {
  final Barcode barcode;

  const BarcodeInfoScreen({Key? key, required this.barcode}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // URL from the barcode raw value
    final String barcodeUrl = barcode.rawValue ?? 'No URL found';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Barcode Information'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Raw Value:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(barcode.rawValue ?? 'N/A'),
            const SizedBox(height: 16),
            const Text(
              'Display Value:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(barcode.displayValue ?? 'N/A'),
            const SizedBox(height: 16),
            const Text(
              'Format:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(barcode.format.name),
            const SizedBox(height: 16),
            const Text(
              'Type:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(barcode.type.name),
            const SizedBox(height: 16),

            // Display barcode URL (if available) and a button to open the link
            if (barcodeUrl.isNotEmpty && barcodeUrl != 'No URL found')
              Column(
                children: [
                  const SizedBox(height: 16),
                  Text(
                    'Barcode Link: $barcodeUrl',
                    style: TextStyle(fontSize: 16, color: Colors.blue),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => _launchURL(barcodeUrl),
                    child: const Text('Open Link'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  // Launch the barcode URL using url_launcher
  void _launchURL(String url) async {
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Could not launch $url';
    }
  }
}
