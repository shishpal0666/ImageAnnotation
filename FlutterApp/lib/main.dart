import 'package:flutter/material.dart';
import 'package:camera/camera.dart'; // Still needed for XFile? Actually ImagePicker uses XFile from cross_file/image_picker.
// But we might need camera package if we keep using CameraDescription? No, we are removing that.
// We can remove camera package import if not used, but let's keep it if main.dart imported it.
// Actually ImagePicker returns XFile. content of main.dart uses XFile. 
// Standard image_picker uses XFile. 
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'screens/annotation_screen.dart';
import 'screens/results_screen.dart';
import 'services/api_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // No more camera initialization here
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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // 1. Initial Permission Check on Home Load
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    // Request Location
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    
    // Request Camera (handled implicitly on Web by browser, but we can try to "warm up" if needed, 
    // but usually better to wait for action. However, user asked for it "On home page".
    // Geolocator is the critical one they mentioned for "location" specifically.
    // We strictly enforce location in _getMandatoryLocation later too.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Image Annotation Home')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ImageSelectionScreen()),
                );
              },
              child: const Text('Add Annotation', style: TextStyle(fontSize: 18)),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              onPressed: () {
                print("Search Pressed");
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ImageSelectionScreen(isSearch: true)),
                );
              },
              child: const Text('Search', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }
}

class ImageSelectionScreen extends StatefulWidget {
  final bool isSearch;
  const ImageSelectionScreen({super.key, this.isSearch = false});

  @override
  State<ImageSelectionScreen> createState() => _ImageSelectionScreenState();
}

class _ImageSelectionScreenState extends State<ImageSelectionScreen> {
  final ImagePicker _picker = ImagePicker();
  final ApiService _apiService = ApiService();
  bool _isLoading = false;

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
      return null;
    }

    // 2. Check the app's permission status
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (!mounted) return null;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission is mandatory to use this app.')),
        );
        return null;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location permissions are permanently denied.')),
      );
      return null;
    } 

    return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }

  Future<void> _processImage(XFile image) async {
    if (widget.isSearch) {
       setState(() => _isLoading = true);
       try {
         // TODO: Get real location (we already checked permission, we can fetch again or pass it)
         // For now, let's fetch it again to be precise or use a cached one if we had it.
         // Calling getCurrentPosition is fast enough if permission is granted.
         final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
         
         final results = await _apiService.searchImage(
           image: image,
           lat: position.latitude, 
           lon: position.longitude,
         );
         
         if (!mounted) return;
         setState(() => _isLoading = false);

         Navigator.push(
           context,
           MaterialPageRoute(
             builder: (context) => ResultsScreen(queryImage: image, results: results),
           ),
         );
       } catch (e) {
         if (!mounted) return;
         setState(() => _isLoading = false);
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
       }
    } else {
      // Should be cached/fast since we checked permissions
      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AnnotationScreen(image: image, position: position),
        ),
      );
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    // 1. Mandatory Location Check before Action
    Position? location = await _getMandatoryLocation();
    if (location == null) return;

    print("Location Verified: ${location.latitude}, ${location.longitude}");

    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 70,
        // preferredCameraDevice is ignored if source is gallery
        preferredCameraDevice: CameraDevice.rear, // Default, but native app lets user switch
      );

      if (image != null) {
        if (!mounted) return;
        await _processImage(image);
      }
    } catch (e) {
      print("Error picking image: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error picking image: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.isSearch ? 'Search Image' : 'Select Image')),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // CAPTURE BUTTON
                SizedBox(
                  width: 250,
                  height: 60,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.camera_alt, size: 30),
                    label: const Text("Capture Photo", style: TextStyle(fontSize: 20)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => _pickImage(ImageSource.camera),
                  ),
                ),
                const SizedBox(height: 30),
                
                // UPLOAD BUTTON
                SizedBox(
                  width: 250,
                  height: 60,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.photo_library, size: 30),
                    label: const Text("Upload from Gallery", style: TextStyle(fontSize: 20)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => _pickImage(ImageSource.gallery),
                  ),
                ),
                
                const SizedBox(height: 20),
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    "Note: Location access is required.",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
    );
  }
}
