import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:calorie_tracker/services/error_service.dart';

class BarcodeService {
  // API URL for barcode lookup
  static String get _apiBaseUrl {
    // Based on the memory about CORS issues, we need to handle web platform differently
    if (kIsWeb) {
      return 'http://localhost:8000'; // Local development server for web
    } else {
      // For mobile devices, use the server IP directly
      // You may need to adjust this IP address based on your network setup
      return 'http://172.20.10.3:8000';
    }
  }

  /// Fetch product information by barcode from the FastAPI backend
  static Future<Map<String, dynamic>> getProductByBarcode(String barcode) async {
    try {
      final Uri url = Uri.parse('$_apiBaseUrl/urun/$barcode');
      
      print('Barkod API isteği yapılıyor: $url');
      
      // Add CORS headers for web requests
      final Map<String, String> headers = kIsWeb 
          ? {'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*'}
          : {'Content-Type': 'application/json'};
      
      final response = await http.get(
        url,
        headers: headers,
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          print('Barkod API isteği zaman aşımına uğradı');
          throw Exception('Bağlantı zaman aşımına uğradı. Lütfen internet bağlantınızı kontrol edin.');
        },
      );
      
      print('Barkod API yanıtı alındı: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Barkod tanıma sonucu: $data');
        return data;
      } else if (response.statusCode == 404) {
        throw Exception('Ürün bulunamadı. Lütfen farklı bir barkod deneyin.');
      } else {
        throw Exception('API hatası: ${response.statusCode} - ${response.body}');
      }
    } catch (e, stackTrace) {
      await ErrorService().logError(e, stackTrace, context: 'barcode_lookup_error');
      print('Barkod arama hatası: $e');
      rethrow;
    }
  }
}
