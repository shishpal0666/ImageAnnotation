import 'package:flutter/material.dart';
import 'dart:io';

class ResultsScreen extends StatefulWidget {
  final File queryImage;
  final List<Map<String, dynamic>> results;

  const ResultsScreen({
    super.key,
    required this.queryImage,
    required this.results,
  });

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  // Assuming the user just wants to see the image and the list of matching annotations.
  // The (x, y) coordinates returned from the API are relative to the original image in the DB,
  // not this query image. Overlaying them directly might be confusing without alignment.
  // We'll focus on the list view and potentially mark points if they are deemed useful.

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search Results')),
      body: Stack(
        children: [
          // Layer 1: Query Image
          Positioned.fill(
            child: Image.file(
              widget.queryImage,
              fit: BoxFit.contain,
            ),
          ),
          
          // Layer 2: List View at the bottom via DraggableScrollableSheet
          DraggableScrollableSheet(
            initialChildSize: 0.3,
            minChildSize: 0.1,
            maxChildSize: 0.6,
            builder: (BuildContext context, ScrollController scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      offset: Offset(0, -5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 50,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: widget.results.isEmpty
                          ? const Center(child: Text("No matches found."))
                          : ListView.builder(
                              controller: scrollController,
                              itemCount: widget.results.length,
                              itemBuilder: (context, index) {
                                final result = widget.results[index];
                                final desc = result['description'] ?? 'No description';
                                final coords = result['coordinates'];
                                final x = coords != null ? coords['x'] : '?';
                                final y = coords != null ? coords['y'] : '?';

                                return ListTile(
                                  leading: CircleAvatar(
                                    child: Text("${index + 1}"),
                                  ),
                                  title: Text(desc),
                                  subtitle: Text("Located at ($x, $y)"), // Display coords
                                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                                  onTap: () {
                                    // Highlight logic could go here if we were overlaying points
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
