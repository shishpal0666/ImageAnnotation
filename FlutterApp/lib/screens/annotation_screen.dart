import 'package:flutter/material.dart';
import 'package:camera/camera.dart'; // For XFile
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../services/api_service.dart'; // Import ApiService

class AnnotationScreen extends StatefulWidget {
  final XFile image;

  const AnnotationScreen({super.key, required this.image});

  @override
  State<AnnotationScreen> createState() => _AnnotationScreenState();
}

class _AnnotationScreenState extends State<AnnotationScreen> {
  List<Map<String, dynamic>> annotations = [];
  final ApiService _apiService = ApiService();

  void _handleTapUp(TapUpDetails details) {
    double x = details.localPosition.dx;
    double y = details.localPosition.dy;

    print("Tapped at: $x, $y");
    
    _showTextInputDialog(x, y);
  }

  Future<void> _showTextInputDialog(double x, double y) async {
    String? text = await showDialog<String>(
      context: context,
      builder: (context) {
        String value = '';
        return AlertDialog(
          title: const Text('Enter Annotation'),
          content: TextField(
            autofocus: true,
            decoration: const InputDecoration(hintText: "Description"),
            onChanged: (text) {
              value = text;
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, value),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (text != null && text.isNotEmpty) {
      print("Annotation: $text at ($x, $y)");
      setState(() {
        annotations.add({
          'x': x,
          'y': y,
          'text': text,
        });
      });
      
      // Upload to Backend
      // Placeholder coordinates for Lat/Lon (Use Geolocator in production)
      await _apiService.uploadAnnotation(
        image: widget.image,
        lat: 40.7128, 
        lon: -74.0060,
        x: x,
        y: y,
        description: text,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Annotation Uploaded!")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Annotate Image')),
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTapUp: _handleTapUp,
              child: kIsWeb 
                ? Image.network(widget.image.path, fit: BoxFit.contain)
                : Image.file(File(widget.image.path), fit: BoxFit.contain),
            ),
          ),
          ...annotations.map((ann) {
            return Positioned(
              left: ann['x'] - 12,
              top: ann['y'] - 12,
              child: const Icon(Icons.location_on, color: Colors.red, size: 24),
            );
          }),
        ],
      ),
    );
  }
}
