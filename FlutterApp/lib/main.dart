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
  CameraDevice _selectedCamera = CameraDevice.rear;

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

  Future<Position?> _getMandatoryLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // 1. Check if the phone's GPS is actually turned on
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location services are disabled. Please turn on GPS.')),
      );
      return null; // Stop here
    }

    // 2. Check the app's permission status
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      // 3. Ask the user for permission
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (!mounted) return null;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission is mandatory to use this app.')),
        );
        return null; // Stop here
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location permissions are permanently denied, we cannot request permissions.')),
      );
      return null; // Stop here
    } 

    // 4. If everything is approved, get the exact coordinates!
    return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }

  Future<void> _pickImage() async {
    // 1. Force the location check FIRST
    Position? userLocation = await _getMandatoryLocation();
    
    // 2. If they denied it, userLocation is null, so we abort.
    if (userLocation == null) return; 

    // TODO: Pass this location to the next screen or API service?
    // For now, we just print it as per instructions, but ideally we'd store it.
    print("User Location: ${userLocation.latitude}, ${userLocation.longitude}");

    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 70,
    );
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
            heroTag: "toggle",
            mini: true,
            backgroundColor: Colors.grey,
            onPressed: () {
              setState(() {
                _selectedCamera = _selectedCamera == CameraDevice.rear 
                    ? CameraDevice.front 
                    : CameraDevice.rear;
              });
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_selectedCamera == CameraDevice.rear 
                      ? 'Switched to Back Camera' 
                      : 'Switched to Front Camera'),
                  duration: const Duration(milliseconds: 500),
                ),
              );
            },
            child: Icon(
              _selectedCamera == CameraDevice.rear 
                  ? Icons.camera_front 
                  : Icons.camera_rear,
            ),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: "camera",
            onPressed: () async {
              // 1. Force the location check FIRST
              Position? userLocation = await _getMandatoryLocation();
              
              // 2. If they denied it, userLocation is null, so we abort.
              if (userLocation == null) return; 

              try {
                // Use image_picker for robust mobile web capture with toggle support
                final XFile? image = await _picker.pickImage(
                  source: ImageSource.camera,
                  preferredCameraDevice: _selectedCamera,
                  maxWidth: 800,
                  maxHeight: 800,
                  imageQuality: 70,
                );
                
                if (image != null) {
                  if (!mounted) return;
                  await _processImage(image);
                }
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
