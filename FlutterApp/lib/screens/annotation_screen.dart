import 'package:flutter/material.dart';
import 'dart:io';

class AnnotationScreen extends StatefulWidget {
  final String imagePath;

  const AnnotationScreen({super.key, required this.imagePath});

  @override
  State<AnnotationScreen> createState() => _AnnotationScreenState();
}

class _AnnotationScreenState extends State<AnnotationScreen> {
  // Store annotations as a list of temporary markers for UI feedback
  // In a real app, these might come from the server or be stored locally
  List<Map<String, dynamic>> annotations = [];

  void _handleTapUp(TapUpDetails details) {
    // Get local coordinates relative to the image widget
    // Note: This assumes the image fits the screen or the widget size matches the image aspect ratio.
    // In production, you'd need to map widget coordinates to actual image pixel coordinates.
    // For this prototype, we'll send widget coordinates and let the backend/frontend logic align.
    // However, the backend expects pixel coordinates if we are doing SIFT.
    // Let's assume for now we just capture what we can.
    
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
      
      // TODO: Send to backend (NodeGateway)
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
              child: Image.file(
                File(widget.imagePath),
                fit: BoxFit.contain, 
                // Using BoxFit.contain ensures the image is visible fully.
                // Coordinates will be relative to the Image widget's box.
              ),
            ),
          ),
          // Display markers
          ...annotations.map((ann) {
            return Positioned(
              left: ann['x'] - 12, // Center icon
              top: ann['y'] - 12,
              child: const Icon(Icons.location_on, color: Colors.red, size: 24),
            );
          }),
        ],
      ),
    );
  }
}
