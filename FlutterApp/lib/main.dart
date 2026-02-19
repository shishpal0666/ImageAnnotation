import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'screens/annotation_screen.dart';
import 'screens/results_screen.dart';
import 'services/api_service.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    cameras = await availableCameras();
  } on CameraException catch (e) {
    print('Error initializing camera: $e');
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Image Annotation',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Image Annotation Home')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CameraScreen()),
                );
              },
              child: const Text('Add Annotation'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                print("Search Pressed");
                // For now, search also goes via CameraScreen or could be a separate picker flow
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CameraScreen(isSearch: true)),
                );
              },
              child: const Text('Search'),
            ),
          ],
        ),
      ),
    );
  }
}

class CameraScreen extends StatefulWidget {
  final bool isSearch;
  const CameraScreen({super.key, this.isSearch = false});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? controller;
  final ImagePicker _picker = ImagePicker();
  bool _isCameraAvailable = false;
  final ApiService _apiService = ApiService();

  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (cameras.isNotEmpty) {
      _isCameraAvailable = true;
      // CRITICAL FIX: Use ResolutionPreset.medium (High/Max crashes Web)
      controller = CameraController(
        cameras[0], 
        ResolutionPreset.medium,
        enableAudio: false, // Turn off audio
      );
      controller!.initialize().then((_) {
        if (!mounted) return;
        setState(() {});
      }).catchError((Object e) {
        // Handle camera errors gracefully
        setState(() {
          _isCameraAvailable = false;
          _errorMessage = e.toString();
        });
      });
    } else {
      _isCameraAvailable = false;
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  Future<void> _processImage(XFile image) async {
    if (widget.isSearch) {
       // Show loading indicator
       showDialog(
         context: context,
         barrierDismissible: false,
         builder: (context) => const Center(child: CircularProgressIndicator()),
       );

       try {
         // TODO: Get real location
         final results = await _apiService.searchImage(
           image: image,
           lat: 40.7128, 
           lon: -74.0060,
         );
         
         if (!mounted) return;
         Navigator.pop(context); // Dismiss loading

         Navigator.push(
           context,
           MaterialPageRoute(
             builder: (context) => ResultsScreen(queryImage: image, results: results),
           ),
         );
       } catch (e) {
         if (!mounted) return;
         Navigator.pop(context); // Dismiss loading
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
       }
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AnnotationScreen(image: image),
        ),
      );
    }
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      if (!mounted) return;
      await _processImage(image);
    }
  }

  @override
  Widget build(BuildContext context) {
    // If camera is not available or not initialized, show Pick Image button
    if (!_isCameraAvailable || controller == null || !controller!.value.isInitialized) {
      return Scaffold(
        appBar: AppBar(title: const Text('Select Image')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 50, color: Colors.orange),
              const SizedBox(height: 10),
              const Text(
                "Camera unavailable on this browser.",
                style: TextStyle(fontSize: 16),
              ),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 20),
              if (!_isCameraAvailable)
                ElevatedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.upload_file),
                  label: const Text("Upload Image Instead"),
                ),
               if (_isCameraAvailable) // Still initializing or just failed but flag not set yet
                 const CircularProgressIndicator(),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: CameraPreview(controller!),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
           FloatingActionButton(
            heroTag: "gallery",
            onPressed: _pickImage,
            child: const Icon(Icons.photo_library),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: "camera",
            onPressed: () async {
              try {
                final image = await controller!.takePicture();
                if (!mounted) return;
                await _processImage(image);
              } catch (e) {
                print(e);
              }
            },
            child: const Icon(Icons.camera),
          ),
        ],
      ),
    );
  }
}
