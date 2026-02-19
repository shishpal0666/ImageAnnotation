import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:camera/camera.dart'; // For XFile
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/annotation_result.dart';

class ApiService {
  // Use 10.0.2.2 for Android Emulator, localhost for Web
  // This looks for a variable passed during the build command. 
  // If not found, it defaults to localhost for local testing.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL', 
    defaultValue: 'http://localhost:3000'
  );

  // NEW: Submit Batch Annotations
  Future<bool> submitBatchAnnotations({
    required XFile image,
    required double lat,
    required double lon,
    required String annotationsJson, // JSON String of List<LocalAnnotation>
  }) async {
    final uri = Uri.parse('$baseUrl/bulk-annotate');
    var request = http.MultipartRequest('POST', uri);

    request.fields['lat'] = lat.toString();
    request.fields['lon'] = lon.toString();
    request.fields['annotationsData'] = annotationsJson;

    if (kIsWeb) {
      request.files.add(http.MultipartFile.fromBytes(
        'image',
        await image.readAsBytes(),
        filename: image.name,
      ));
    } else {
      request.files.add(await http.MultipartFile.fromPath('image', image.path));
    }

    try {
      var response = await request.send();
      if (response.statusCode == 200) { // Success is usually 200 OK
        return true;
      } else {
        print('Batch upload failed with status: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print("Error uploading batch: $e");
      return false;
    }
  }

  Future<void> uploadAnnotation({
    required XFile image,
    required double lat,
    required double lon,
    required double x,
    required double y,
    required String description,
  }) async {
    final uri = Uri.parse('$baseUrl/upload');
    var request = http.MultipartRequest('POST', uri);

    request.fields['lat'] = lat.toString();
    request.fields['lon'] = lon.toString();
    request.fields['x'] = x.toString();
    request.fields['y'] = y.toString();
    request.fields['description'] = description;

    if (kIsWeb) {
      request.files.add(http.MultipartFile.fromBytes(
        'image',
        await image.readAsBytes(),
        filename: image.name,
      ));
    } else {
      request.files.add(await http.MultipartFile.fromPath('image', image.path));
    }

    try {
      var response = await request.send();
      if (response.statusCode == 201) {
        print("Upload successful");
        var responseData = await response.stream.bytesToString();
        print(responseData);
      } else {
        print("Upload failed: ${response.statusCode}");
      }
    } catch (e) {
      print("Error uploading annotation: $e");
    }
  }

  Future<List<AnnotationResult>> searchImage({
    required XFile image,
    required double lat,
    required double lon,
  }) async {
    final uri = Uri.parse('$baseUrl/search');
    var request = http.MultipartRequest('POST', uri);

    request.fields['lat'] = lat.toString();
    request.fields['lon'] = lon.toString();

    if (kIsWeb) {
      request.files.add(http.MultipartFile.fromBytes(
        'image',
        await image.readAsBytes(),
        filename: image.name,
      ));
    } else {
      request.files.add(await http.MultipartFile.fromPath('image', image.path));
    }

    try {
      var response = await request.send();
      if (response.statusCode == 200) {
        var responseData = await response.stream.bytesToString();
        List<dynamic> jsonResponse = jsonDecode(responseData);
        
        return jsonResponse.map((item) => AnnotationResult.fromJson(item)).toList();
      } else {
        print("Search failed: ${response.statusCode}");
        return [];
      }
    } catch (e) {
      print("Error searching image: $e");
      return [];
    }
  }
}
