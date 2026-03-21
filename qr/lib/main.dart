import 'dart:convert';
import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:gal/gal.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: QRGenerator(),
    );
  }
}

class QRGenerator extends StatefulWidget {
  const QRGenerator({super.key});

  @override
  State<QRGenerator> createState() => _QRGeneratorState();
}

class _QRGeneratorState extends State<QRGenerator> {
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  final GlobalKey _qrKey = GlobalKey();

  String _qrData = "";
  bool _isSaving = false;

  void _generateData() {
    if (_idController.text.isNotEmpty && _nameController.text.isNotEmpty) {
      Map<String, String> dataMap = {
        "id": _idController.text,
        "name": _nameController.text,
      };
      setState(() {
        _qrData = jsonEncode(dataMap);
      });
    } else {
      setState(() {
        _qrData = "";
      });
    }
  }

  // ✅ Works for Android 11 → 13+
  Future<bool> _requestPermission() async {
    // Already granted?
    if (await Permission.photos.isGranted ||
        await Permission.storage.isGranted) {
      return true;
    }

    // Try both (Android handles the correct one)
    final photos = await Permission.photos.request();
    final storage = await Permission.storage.request();

    return photos.isGranted || storage.isGranted;
  }

  Future<void> _saveQrToGallery() async {
    setState(() => _isSaving = true);

    try {
      // 1. Permission
      bool hasPermission = await _requestPermission();
      if (!hasPermission) {
        _showMessage("Permission denied", Colors.red);
        return;
      }

      // 2. Capture widget
      RenderRepaintBoundary? boundary =
          _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;

      if (boundary == null) {
        _showMessage("Error capturing QR", Colors.red);
        return;
      }

      // 3. Convert to image
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);

      ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );

      if (byteData == null) {
        _showMessage("Error generating image", Colors.red);
        return;
      }

      Uint8List pngBytes = byteData.buffer.asUint8List();

      // 4. Save image using gal
      final fileName =
          "qr_${_idController.text}_${DateTime.now().millisecondsSinceEpoch}.png";

      await Gal.putImageBytes(pngBytes, name: fileName);

      _showMessage("Saved to gallery ✅", Colors.green);
    } catch (e) {
      _showMessage("Error: $e", Colors.red);
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _showMessage(String msg, Color color) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  void dispose() {
    _idController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("QR Generator"), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: _idController,
                decoration: const InputDecoration(
                  labelText: "User ID",
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => _generateData(),
              ),
              const SizedBox(height: 15),

              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: "User Name",
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => _generateData(),
              ),

              const SizedBox(height: 30),

              if (_qrData.isNotEmpty)
                Column(
                  children: [
                    RepaintBoundary(
                      key: _qrKey,
                      child: Container(
                        color: Colors.white,
                        padding: const EdgeInsets.all(10),
                        child: QrImageView(data: _qrData, size: 250),
                      ),
                    ),

                    const SizedBox(height: 20),

                    _isSaving
                        ? const CircularProgressIndicator()
                        : ElevatedButton.icon(
                            onPressed: _saveQrToGallery,
                            icon: const Icon(Icons.download),
                            label: const Text("Save QR"),
                          ),
                  ],
                )
              else
                const Text("Enter ID & Name to generate QR"),
            ],
          ),
        ),
      ),
    );
  }
}
