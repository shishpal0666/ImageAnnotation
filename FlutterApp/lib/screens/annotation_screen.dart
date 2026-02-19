import 'package:flutter/material.dart';
import 'package:camera/camera.dart'; // For XFile
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../services/api_service.dart'; // Import ApiService
import '../models/local_annotation.dart';

class AnnotationScreen extends StatefulWidget {
  final XFile image;

  const AnnotationScreen({super.key, required this.image});

  @override
  State<AnnotationScreen> createState() => _AnnotationScreenState();
}

class _AnnotationScreenState extends State<AnnotationScreen> {
  final ApiService _apiService = ApiService();
  List<LocalAnnotation> _annotations = [];
  int _counter = 1;

  void _addAnnotationPoint(double x, double y) {
    TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Add Annotation"),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: "What is this?"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                setState(() {
                  _annotations.add(LocalAnnotation(
                    id: _counter++,
                    x: x,
                    y: y,
                    description: controller.text,
                  ));
                });
                Navigator.pop(context);
              }
            },
            child: const Text("Save"),
          )
        ],
      ),
    );
  }

  void _editAnnotation(int index) {
    TextEditingController controller = TextEditingController(text: _annotations[index].description);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Edit Annotation #${_annotations[index].id}"),
        content: TextField(controller: controller),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _annotations.removeAt(index);
              });
              Navigator.pop(context);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _annotations[index].description = controller.text;
              });
              Navigator.pop(context);
            },
            child: const Text("Update"),
          )
        ],
      ),
    );
  }

  Future<void> _submitBatch() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    String annotationsJson = jsonEncode(_annotations.map((a) => a.toJson()).toList());

    bool success = await _apiService.submitBatchAnnotations(
      image: widget.image,
      lat: 40.7128, // TODO: Get real location
      lon: -74.0060,
      annotationsJson: annotationsJson,
    );

    if (mounted) {
      Navigator.pop(context); // Dismiss loading
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Batch uploaded successfully!")),
        );
        Navigator.pop(context); // Go back to Home
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Upload failed. Check logs.")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Batch Annotation')),
      body: Column(
        children: [
          // --- TOP HALF: IMAGE & MARKERS ---
          Expanded(
            flex: 2,
            child: GestureDetector(
              onTapUp: (details) => _addAnnotationPoint(details.localPosition.dx, details.localPosition.dy),
              child: Stack(
                children: [
                  // The Image
                  SizedBox(
                    width: double.infinity,
                    height: double.infinity,
                    child: kIsWeb 
                        ? Image.network(widget.image.path, fit: BoxFit.contain)
                        : Image.file(File(widget.image.path), fit: BoxFit.contain),
                  ),
                  // The Markers overlay
                  ..._annotations.map((ann) => Positioned(
                        left: ann.x - 15, // Offset by half the width to center the circle
                        top: ann.y - 15,
                        child: GestureDetector(
                          onTap: () {
                            // Find index of this annotation
                            int index = _annotations.indexOf(ann);
                            _editAnnotation(index);
                          },
                          child: CircleAvatar(
                            radius: 15,
                            backgroundColor: Colors.red,
                            child: Text(ann.id.toString(), style: const TextStyle(color: Colors.white, fontSize: 12)),
                          ),
                        ),
                      )),
                ],
              ),
            ),
          ),

          // --- BOTTOM HALF: LIST & SUBMIT BUTTON ---
          Expanded(
            flex: 1,
            child: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: _annotations.length,
                    itemBuilder: (context, index) {
                      final ann = _annotations[index];
                      return ListTile(
                        leading: CircleAvatar(child: Text(ann.id.toString())),
                        title: Text(ann.description),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _editAnnotation(index),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.cloud_upload),
                    label: Text('Submit ${_annotations.length} Annotations'),
                    onPressed: _annotations.isNotEmpty ? _submitBatch : null,
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}
