import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiService {
  // Use 10.0.2.2 for Android Emulator to access host localhost
  static const String baseUrl = 'http://10.0.2.2:3000';

  Future<void> uploadAnnotation({
    required File image,
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

    request.files.add(await http.MultipartFile.fromPath('image', image.path));

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

  Future<List<Map<String, dynamic>>> searchImage({
    required File image,
    required double lat,
    required double lon,
  }) async {
    final uri = Uri.parse('$baseUrl/search');
    var request = http.MultipartRequest('POST', uri);

    request.fields['lat'] = lat.toString();
    request.fields['lon'] = lon.toString();

    request.files.add(await http.MultipartFile.fromPath('image', image.path));

    try {
      var response = await request.send();
      if (response.statusCode == 200) {
        var responseData = await response.stream.bytesToString();
        List<dynamic> jsonResponse = jsonDecode(responseData);
        
        // Convert to List<Map<String, dynamic>>
        return jsonResponse.map((item) => item as Map<String, dynamic>).toList();
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
