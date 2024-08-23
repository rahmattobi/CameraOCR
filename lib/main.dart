// ignore_for_file: avoid_web_libraries_in_flutter, avoid_print

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html; 
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  final firstCamera = cameras.first;

  runApp(
    MaterialApp(
      theme: ThemeData.dark(),
      home: TakePictureScreen(
        camera: firstCamera,
      ),
    ),
  );
}

class TakePictureScreen extends StatefulWidget {
  final CameraDescription camera;

  const TakePictureScreen({
    super.key,
    required this.camera,
  });

  @override
  TakePictureScreenState createState() => TakePictureScreenState();
}

class TakePictureScreenState extends State<TakePictureScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;

  @override
  void initState() {
    super.initState();
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.veryHigh,
    );
    _initializeControllerFuture = _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<String> _convertBlobToBase64(String blobUrl) async {
    final response = await html.HttpRequest.request(
      blobUrl,
      responseType: 'blob',
    );
    final blob = response.response as html.Blob;

    final reader = html.FileReader();
    reader.readAsArrayBuffer(blob);
    await reader.onLoadEnd.first;

    final data = reader.result as Uint8List;
    return base64Encode(data);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Testing Camera')),
      body: Stack(
        children: [
          FutureBuilder<void>(
            future: _initializeControllerFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done) {
                return LayoutBuilder(
                  builder: (context, constraints) {
                    return Center(
                      child: AspectRatio(
                        aspectRatio: _controller.value.aspectRatio,
                        child: CameraPreview(_controller),
                      ),
                    );
                  },
                );
              } else {
                return const Center(child: CircularProgressIndicator());
              }
            },
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20.0),
              child: FloatingActionButton(
                onPressed: () async {
                  try {
                    await _initializeControllerFuture;
                    final image = await _controller.takePicture();

                    final base64Image = await _convertBlobToBase64(image.path);
                    print('Base64 Image: $base64Image');

                    if (!context.mounted) return;
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => DisplayPictureScreen(
                          base64Image: base64Image,
                        ),
                      ),
                    );
                  } catch (e) {
                    print(e);
                  }
                },
                child: const Icon(Icons.camera_alt),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DisplayPictureScreen extends StatelessWidget {
  final String base64Image;

  const DisplayPictureScreen({super.key, required this.base64Image});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hasil Tangkapan Camera')),
      body: Column(
        children: [
          Expanded(
            child: Image.memory(
              base64Decode(base64Image),
              fit: BoxFit.cover,
              width: double.infinity,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () {
                    _saveImage(base64Image);
                  },
                  child: const Text('Download'),
                ),
                ElevatedButton(
                  onPressed: () {
                    _previewImage(context, base64Image);
                  },
                  child: const Text('Preview'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _saveImage(String base64Image) {
    final bytes = base64Decode(base64Image);
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute("download", "image.png")
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  void _previewImage(BuildContext context, String base64Image) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Preview Gambar')),
          body: Center(
            child: Image.memory(
              base64Decode(base64Image),
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}
