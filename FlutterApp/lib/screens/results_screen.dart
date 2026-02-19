import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart'; // For XFile
import '../models/annotation_result.dart';
import '../services/api_service.dart';

class ResultsScreen extends StatelessWidget {
  final XFile queryImage; // The image the user just searched with
  final List<AnnotationResult> results; // The data from Node.js

  const ResultsScreen({Key? key, required this.queryImage, required this.results}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search Results')),
      body: Column(
        children: [
          // --- TOP HALF: IMAGE PREVIEW ---
          Expanded(
            flex: 1, // Takes up 50% of the screen
            child: Container(
              width: double.infinity,
              color: Colors.black12,
              child: kIsWeb
                  // On Flutter Web, we use Image.network for XFile paths
                  ? Image.network(queryImage.path, fit: BoxFit.contain)
                  // On Mobile, we use Image.file
                  : Image.file(File(queryImage.path), fit: BoxFit.contain),
            ),
          ),
          
          // --- BOTTOM HALF: RESULTS & DISTANCES ---
          Expanded(
            flex: 1, // Takes up the remaining 50%
            child: results.isEmpty
                ? const Center(child: Text("No matching annotations found."))
                : ListView.builder(
                    itemCount: results.length,
                    itemBuilder: (context, index) {
                      final res = results[index];
                      
                      // Optional: Color code the distance (Lower is better)
                      Color scoreColor = res.distance < 150 ? Colors.green : Colors.orange;

                      // Debug URL
                      print('Trying to load image from: ${ApiService.baseUrl}${res.imageUrl}');

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: ListTile(
                          leading: res.imageUrl != null 
                              ? Image.network(
                                  // Construct full URL using ApiService.baseUrl + relative path
                                  '${ApiService.baseUrl}${res.imageUrl}',
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image),
                                )
                              : const Icon(Icons.image_not_supported, size: 60),
                          title: Text(
                            res.description,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text('Distance Score: ${res.distance.toStringAsFixed(2)}'),
                          trailing: Icon(
                            res.distance < 150 ? Icons.check_circle : Icons.warning,
                            color: scoreColor,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
