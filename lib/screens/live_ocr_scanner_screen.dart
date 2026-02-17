import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';

class LiveOcrScannerScreen extends StatefulWidget {
  const LiveOcrScannerScreen({super.key});

  @override
  State<LiveOcrScannerScreen> createState() => _LiveOcrScannerScreenState();
}

class _LiveOcrScannerScreenState extends State<LiveOcrScannerScreen> {
  CameraController? _cameraController;
  final TextRecognizer _textRecognizer = TextRecognizer();
  bool _isAnalyzing = false;
  File? _capturedImage;
  RecognizedText? _recognizedText;
  Size? _imageSize;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    _cameraController = CameraController(
      cameras[0],
      ResolutionPreset.high,
      enableAudio: false,
    );

    await _cameraController?.initialize();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  Future<void> _takePicture() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized)
      return;

    try {
      setState(() => _isAnalyzing = true);

      final XFile photo = await _cameraController!.takePicture();
      final File imageFile = File(photo.path);

      // Get image dimensions for proper scaling
      final decodedImage = await decodeImageFromList(
        await imageFile.readAsBytes(),
      );

      final inputImage = InputImage.fromFile(imageFile);
      final recognizedText = await _textRecognizer.processImage(inputImage);

      if (mounted) {
        setState(() {
          _capturedImage = imageFile;
          _recognizedText = recognizedText;
          _imageSize = Size(
            decodedImage.width.toDouble(),
            decodedImage.height.toDouble(),
          );
          _isAnalyzing = false;
        });
      }
    } catch (e) {
      debugPrint('Error taking picture/matching OCR: $e');
      setState(() => _isAnalyzing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          _capturedImage == null ? 'Focar Produto' : 'Selecionar Nome',
        ),
        backgroundColor: Colors.black.withOpacity(0.5),
        actions: [
          if (_capturedImage != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => setState(() {
                _capturedImage = null;
                _recognizedText = null;
              }),
            ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Show Camera or Captured Image
          if (_capturedImage == null)
            CameraPreview(_cameraController!)
          else
            Image.file(_capturedImage!, fit: BoxFit.contain),

          // OCR Overlays (only if image is captured)
          if (_capturedImage != null && _recognizedText != null)
            _buildInteractiveOverlays(),

          // Shutter or Loading
          if (_capturedImage == null) _buildShutterButton(),

          if (_isAnalyzing)
            const Center(child: CircularProgressIndicator(color: Colors.white)),

          if (_capturedImage == null)
            _buildInstructions('Aponte e tire uma foto do nome do produto')
          else if (_recognizedText != null && _recognizedText!.text.isEmpty)
            _buildInstructions('Nenhum texto detectado. Tente novamente.')
          else
            _buildInstructions('Toque no nome do produto correto'),
        ],
      ),
    );
  }

  Widget _buildShutterButton() {
    return Positioned(
      bottom: 60,
      left: 0,
      right: 0,
      child: Center(
        child: GestureDetector(
          onTap: _isAnalyzing ? null : _takePicture,
          child: Container(
            height: 80,
            width: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
            ),
            child: Container(
              margin: const EdgeInsets.all(5),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: _isAnalyzing
                  ? const CircularProgressIndicator(color: Colors.black)
                  : null,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInteractiveOverlays() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate how the image is fitting on the screen
        final double screenWidth = constraints.maxWidth;
        final double screenHeight = constraints.maxHeight;

        final double imageAspectRatio = _imageSize!.width / _imageSize!.height;
        final double screenAspectRatio = screenWidth / screenHeight;

        double scale, offsetX = 0, offsetY = 0;

        if (imageAspectRatio > screenAspectRatio) {
          // Limited by width
          scale = screenWidth / _imageSize!.width;
          offsetY = (screenHeight - (_imageSize!.height * scale)) / 2;
        } else {
          // Limited by height
          scale = screenHeight / _imageSize!.height;
          offsetX = (screenWidth - (_imageSize!.width * scale)) / 2;
        }

        return Stack(
          children: _recognizedText!.blocks.expand((block) {
            return block.lines.map((line) {
              final rect = line.boundingBox;
              return Positioned(
                left: offsetX + (rect.left * scale),
                top: offsetY + (rect.top * scale),
                width: rect.width * scale,
                height: rect.height * scale,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context, line.text.trim()),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.cyanAccent, width: 2),
                      color: Colors.cyanAccent.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        color: Colors.black54,
                        child: Text(
                          line.text,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            });
          }).toList(),
        );
      },
    );
  }

  Widget _buildInstructions(String text) {
    return Positioned(
      top: 10,
      left: 20,
      right: 20,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black45,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            text,
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        ),
      ),
    );
  }
}
