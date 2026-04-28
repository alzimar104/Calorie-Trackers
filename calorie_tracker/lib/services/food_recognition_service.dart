import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:calorie_tracker/services/error_service.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FoodRecognitionService {
  // Vision Processing API URL - Render API
  static const String _renderApiBaseUrl = 'https://vision-processing.onrender.com';
  
  // Yerel FastAPI proxy URL - Web için CORS sorunlarını çözer
  static String get _apiBaseUrl {
    // Web platformunda yerel proxy'yi kullan
    if (kIsWeb) {
      return 'http://localhost:8000';
    }
    // Mobil platformlarda doğrudan Render API'yi kullan
    return _renderApiBaseUrl;
  }
  
  // Custom cache manager for storing API responses
  static final DefaultCacheManager _cacheManager = DefaultCacheManager();
  
  // Method to recognize food from image bytes (works on both web and native platforms)
  static Future<Map<String, dynamic>> recognizeFoodFromBytes(Uint8List imageBytes, String fileName) async {
    try {
      // Optimize image size before sending to API
      final optimizedImageBytes = await _optimizeImageSize(imageBytes);
      
      // API endpoint belirle - web platformunda proxy'yi kullan
      final String endpoint = kIsWeb ? '/recognize_base64' : '/tahmin';
      final Uri apiUrl = Uri.parse('$_apiBaseUrl$endpoint');
      
      print('Görüntü işleme API isteği yapılıyor: $apiUrl');
      print('Görüntü boyutu: ${optimizedImageBytes.length} bytes');
      
      // Web platformunda base64 kodlaması kullan
      if (kIsWeb) {
        // Base64 kodlaması kullanarak gönder (CORS sorunlarını çözmek için)
        final base64Image = base64Encode(optimizedImageBytes);
        final response = await http.post(
          apiUrl,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'image': 'data:image/jpeg;base64,$base64Image'}),
        ).timeout(
          const Duration(seconds: 60),
          onTimeout: () {
            print('API isteği zaman aşımına uğradı - yedek veri aranacak');
            throw Exception('Bağlantı zaman aşımına uğradı. Lütfen internet bağlantınızı kontrol edin.');
          },
        );
        
        print('API yanıtı alındı: ${response.statusCode}');
        
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          print('Yemek tanıma sonucu: $data');
          await _cacheResponse(fileName, data);
          return data;
        } else {
          throw Exception('API hatası: ${response.statusCode} - ${response.body}');
        }
      } else {
        // Mobil platformlar için multipart/form-data kullan
        final request = http.MultipartRequest('POST', apiUrl);
        
        // Add file to request using bytes
        request.files.add(
          http.MultipartFile.fromBytes(
            'file', 
            optimizedImageBytes,
            filename: fileName
          )
        );
        
        // Send request with timeout
        final streamedResponse = await request.send().timeout(
          const Duration(seconds: 60),
          onTimeout: () {
            print('API isteği zaman aşımına uğradı - yedek veri aranacak');
            throw Exception('Bağlantı zaman aşımına uğradı. Lütfen internet bağlantınızı kontrol edin.');
          },
        );
        
        // Get response
        final response = await http.Response.fromStream(streamedResponse);
        
        print('API yanıtı alındı: ${response.statusCode}');
        
        if (response.statusCode == 200) {
          // Parse response
          final data = jsonDecode(response.body);
          print('Yemek tanıma sonucu: $data');
          
          // Cache the successful response
          await _cacheResponse(fileName, data);
          
          return data;
        } else {
          // Try to get cached response first
          final cachedData = await _getCachedResponse(fileName);
          if (cachedData != null) {
            print('Önbellek verileri kullanılıyor');
            return cachedData;
          }
          
          throw Exception('API hatası: ${response.statusCode} - ${response.reasonPhrase}');
        }
      }
    } catch (e, stackTrace) {
      // Log error
      await ErrorService().logError(e, stackTrace, context: 'recognizeFoodFromBytes');
      print('Error recognizing food: $e');
      
      // Try to get cached response if there's an error
      final cachedData = await _getCachedResponse(fileName);
      if (cachedData != null) {
        print('Hata sonrası önbellek verileri kullanılıyor');
        return cachedData;
      }
      
      // If all else fails, return dummy data
      return await getDummyFoodData();
    }
  }
  
  // Optimize image size to reduce API load
  static Future<Uint8List> _optimizeImageSize(Uint8List imageBytes) async {
    try {
      // Skip optimization for web platform
      if (kIsWeb) return imageBytes;
      
      // Skip optimization for small images
      if (imageBytes.length < 500 * 1024) return imageBytes; // Less than 500KB
      
      // Use flutter_image_compress to reduce image size
      final result = await FlutterImageCompress.compressWithList(
        imageBytes,
        minHeight: 1024, // Reasonable height for food recognition
        minWidth: 1024,  // Reasonable width for food recognition
        quality: 85,     // Good quality but smaller size
        format: CompressFormat.jpeg,
      );
      
      print('Görüntü sıkıştırıldı: ${imageBytes.length} → ${result.length} bytes');
      return result;
    } catch (e) {
      print('Görüntü sıkıştırma başarısız: $e');
      return imageBytes; // Return original if compression fails
    }
  }
  
  // Cache successful API responses
  static Future<void> _cacheResponse(String key, Map<String, dynamic> data) async {
    try {
      // Don't cache on web platform
      if (kIsWeb) return;
      
      // Generate a unique but consistent key for this file
      final cacheKey = 'food_recognition_${key.hashCode}';
      
      // Save to cache manager
      await _cacheManager.putFile(
        cacheKey,
        Uint8List.fromList(utf8.encode(jsonEncode(data))),
        fileExtension: 'json',
        maxAge: const Duration(days: 7), // Cache for a week
      );
      
      // Also save to shared preferences for quicker access
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(cacheKey, jsonEncode(data));
      
      print('API yanıtı önbelleğe alındı: $cacheKey');
    } catch (e) {
      print('Önbelleğe alma hatası: $e');
    }
  }
  
  // Get cached response if available
  static Future<Map<String, dynamic>?> _getCachedResponse(String key) async {
    try {
      // Don't use cache on web platform
      if (kIsWeb) return null;
      
      final cacheKey = 'food_recognition_${key.hashCode}';
      
      // First try shared preferences (faster)
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString(cacheKey);
      
      if (cachedData != null) {
        return jsonDecode(cachedData) as Map<String, dynamic>;
      }
      
      // Then try file cache
      final fileInfo = await _cacheManager.getFileFromCache(cacheKey);
      if (fileInfo != null) {
        final content = await fileInfo.file.readAsString();
        return jsonDecode(content) as Map<String, dynamic>;
      }
      
      return null;
    } catch (e) {
      print('Önbellek okuma hatası: $e');
      return null;
    }
  }
  
  // Enhanced dummy method with more realistic data
  static Future<Map<String, dynamic>> getDummyFoodData() async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));
    
    // Multiple dummy food options
    final dummyFoods = [
      {
        'prediction': 'Elma',
        'confidence': 0.95,
        'nutritional_info': {
          'calories': 52,
          'carbohydrates': 14.0,
          'protein': 0.3,
          'fat': 0.2,
          'fiber': 2.4,
          'sugar': 10.3,
          'serving_size': '1 orta boy (182g)'
        }
      },
      {
        'prediction': 'Tavuk Göğsü',
        'confidence': 0.92,
        'nutritional_info': {
          'calories': 165,
          'carbohydrates': 0.0,
          'protein': 31.0,
          'fat': 3.6,
          'fiber': 0.0,
          'sugar': 0.0,
          'serving_size': '100g pişmiş'
        }
      },
      {
        'prediction': 'Pilav',
        'confidence': 0.89,
        'nutritional_info': {
          'calories': 205,
          'carbohydrates': 44.5,
          'protein': 4.3,
          'fat': 0.4,
          'fiber': 0.6,
          'sugar': 0.1,
          'serving_size': '1 porsiyon (150g)'
        }
      },
      {
        'prediction': 'Salata',
        'confidence': 0.94,
        'nutritional_info': {
          'calories': 45,
          'carbohydrates': 8.0,
          'protein': 2.0,
          'fat': 0.5,
          'fiber': 3.0,
          'sugar': 3.2,
          'serving_size': '1 kase (100g)'
        }
      }
    ];
    
    // Return a random food for variety
    final randomIndex = DateTime.now().millisecond % dummyFoods.length;
    return dummyFoods[randomIndex];
  }
  
  // Improved method to convert recognition results to a food item format
  static Map<String, dynamic> convertToFoodItem(Map<String, dynamic> recognitionResult) {
    try {
      print('API yanıtı: $recognitionResult');
      
      // Extract food name
      String foodName = 'Bilinmeyen Yemek';
      if (recognitionResult.containsKey('prediction')) {
        foodName = recognitionResult['prediction'] ?? foodName;
      } else if (recognitionResult.containsKey('food_name')) {
        foodName = recognitionResult['food_name'] ?? foodName;
      }
      
      // Extract nutritional info using safe parsing methods
      Map<String, dynamic> nutritionValues = {};
      
      // First check if we have a nutritional_info object
      if (recognitionResult.containsKey('nutritional_info') && 
          recognitionResult['nutritional_info'] is Map) {
        nutritionValues = recognitionResult['nutritional_info'];
      } 
      // Otherwise look for direct values in the main object
      else {
        ['calories', 'carbohydrates', 'carbs', 'protein', 'fat', 
         'fiber', 'sugar', 'serving_size'].forEach((key) {
          if (recognitionResult.containsKey(key)) {
            nutritionValues[key] = recognitionResult[key];
          }
        });
      }
      
      // Parse values with safe defaults
      final int calories = _parseIntSafely(
        nutritionValues['calories'] ?? recognitionResult['calories']);
      
      final double carbs = _parseDoubleSafely(
        nutritionValues['carbohydrates'] ?? nutritionValues['carbs'] ?? 
        recognitionResult['carbs'] ?? recognitionResult['carbohydrates']);
      
      final double protein = _parseDoubleSafely(
        nutritionValues['protein'] ?? recognitionResult['protein']);
      
      final double fat = _parseDoubleSafely(
        nutritionValues['fat'] ?? recognitionResult['fat']);
      
      final double fiber = _parseDoubleSafely(
        nutritionValues['fiber'] ?? recognitionResult['fiber'] ?? 0);
      
      final double sugar = _parseDoubleSafely(
        nutritionValues['sugar'] ?? recognitionResult['sugar'] ?? 0);
      
      // Extract serving info
      String servingSize = nutritionValues['serving_size'] ?? 
                          recognitionResult['serving_size'] ?? 
                          'Porsiyon';
      
      // Determine serving unit based on food type
      String servingUnit = _determineServingUnit(foodName);
      
      // Create food item with uniquely generated ID
      return {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'foodName': foodName,
        'calories': calories,
        'carbs': carbs,
        'protein': protein,
        'fat': fat,
        'fiber': fiber,
        'sugar': sugar,
        'serving': servingSize,
        'servingAmount': '1',
        'servingUnit': servingUnit,
        'brand': '',
        'addedTime': DateTime.now().toIso8601String(),
      };
    } catch (e, stackTrace) {
      // Log error
      ErrorService().logError(e, stackTrace, context: 'convertToFoodItem');
      print('Error converting recognition result to food item: $e');
      
      // Return default food item
      return {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'foodName': 'Tanımlanamayan Yemek',
        'calories': 0,
        'carbs': 0,
        'protein': 0,
        'fat': 0,
        'fiber': 0,
        'sugar': 0,
        'serving': 'Porsiyon',
        'servingAmount': '1',
        'servingUnit': 'adet',
        'brand': '',
        'addedTime': DateTime.now().toIso8601String(),
      };
    }
  }
  
  // Helper method for safely parsing integer values
  static int _parseIntSafely(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.round();
    try {
      return int.parse(value.toString());
    } catch (e) {
      return 0;
    }
  }
  
  // Helper method for safely parsing double values
  static double _parseDoubleSafely(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    try {
      return double.parse(value.toString());
    } catch (e) {
      return 0.0;
    }
  }
  
  // Determine appropriate serving unit based on food name
  static String _determineServingUnit(String foodName) {
    final foodNameLower = foodName.toLowerCase();
    
    if (foodNameLower.contains('çorba') || 
        foodNameLower.contains('soup') ||
        foodNameLower.contains('içecek') ||
        foodNameLower.contains('sıvı') ||
        foodNameLower.contains('süt') ||
        foodNameLower.contains('su')) {
      return 'ml';
    } else if (foodNameLower.contains('et') ||
               foodNameLower.contains('tavuk') ||
               foodNameLower.contains('balık') ||
               foodNameLower.contains('köfte')) {
      return 'gram';
    } else if (foodNameLower.contains('ekmek') ||
               foodNameLower.contains('dilim')) {
      return 'dilim';
    } else if (foodNameLower.contains('elma') ||
               foodNameLower.contains('muz') ||
               foodNameLower.contains('portakal') ||
               foodNameLower.contains('meyve')) {
      return 'adet';
    }
    
    return 'porsiyon';
  }
  
  /// Yerel JSON dosyasından yemek verilerini yükler
  static Future<List<Map<String, dynamic>>> _loadFoodData() async {
    try {
      // JSON dosyasını oku
      final String jsonString = await rootBundle.loadString('assets/food_and_calories.json');
      final List<dynamic> jsonData = json.decode(jsonString);
      
      // JSON verisini Map listesine dönüştür
      return jsonData.map((item) => item as Map<String, dynamic>).toList();
    } catch (e, stackTrace) {
      await ErrorService().logError(e, stackTrace, context: '_loadFoodData');
      print('JSON dosyasını okuma hatası: $e');
      return [];
    }
  }

  /// Yemek adına göre benzerlik skoru hesaplar (basit string karşılaştırma)
  static double _calculateSimilarity(String food1, String food2) {
    // Küçük harfe çevir ve boşlukları kaldır
    final s1 = food1.toLowerCase().replaceAll('_', ' ');
    final s2 = food2.toLowerCase().replaceAll('_', ' ');
    
    // Tam eşleşme varsa en yüksek skoru döndür
    if (s1 == s2) return 1.0;
    
    // Birisi diğerini içeriyorsa yüksek bir skor döndür
    if (s1.contains(s2) || s2.contains(s1)) return 0.8;
    
    // Basit bir benzerlik hesaplaması - ortak karakterlerin oranı
    final Set<String> chars1 = s1.split('').toSet();
    final Set<String> chars2 = s2.split('').toSet();
    
    final intersection = chars1.intersection(chars2).length;
    final union = chars1.union(chars2).length;
    
    return intersection / union;
  }

  /// Render'daki yemek tanıma projesini yerel JSON dosyası ile entegre eder.
  /// Bu metod, görüntüden tanınan yemeği yerel JSON dosyasında arar
  /// ve eşleşen yemek bilgilerini döndürür.
  static Future<Map<String, dynamic>> recognizeAndMatchWithLocalData(Uint8List imageBytes, String fileName) async {
    try {
      // Önce Render API'den yemek tanıma sonucunu al
      final renderResult = await recognizeFoodFromBytes(imageBytes, fileName);
      print('Render API sonucu: $renderResult');
      
      // Render API'den yemek tahminini al
      String? predictedFoodName;
      double highestProbability = 0.0;
      
      // Farklı API yanıt formatlarını kontrol et
      if (renderResult.containsKey('predictions') && renderResult['predictions'] is List) {
        // Yeni API formatı: predictions listesi içinde class ve probability
        final predictions = renderResult['predictions'] as List;
        for (var prediction in predictions) {
          if (prediction is Map && 
              prediction.containsKey('class') && 
              prediction.containsKey('probability')) {
            final probability = double.tryParse(prediction['probability'].toString()) ?? 0.0;
            if (probability > highestProbability) {
              highestProbability = probability;
              predictedFoodName = prediction['class'].toString();
            }
          }
        }
      } else if (renderResult.containsKey('tahminler') && renderResult['tahminler'] is List) {
        // Türkçe API formatı: tahminler listesi içinde etiket ve olasılık
        final tahminler = renderResult['tahminler'] as List;
        for (var tahmin in tahminler) {
          if (tahmin is Map && tahmin.containsKey('etiket')) {
            // Olasılık alanını kontrol et
            dynamic probabilityValue;
            if (tahmin.containsKey('olasilik')) {
              probabilityValue = tahmin['olasilik'];
            }
            
            if (probabilityValue != null) {
              final probability = double.tryParse(probabilityValue.toString()) ?? 0.0;
              if (probability > highestProbability) {
                highestProbability = probability;
                predictedFoodName = tahmin['etiket'].toString();
                print('Bulunan yemek: ${tahmin['etiket']} - Olasilik: $probability');
              }
            }
          }
        }
      } else if (renderResult.containsKey('prediction')) {
        // Eski API formatı: doğrudan prediction ve confidence
        predictedFoodName = renderResult['prediction'];
        highestProbability = double.tryParse(renderResult['confidence']?.toString() ?? '0') ?? 0.0;
      }
      
      if (predictedFoodName == null) {
        // Tahmin bulunamadıysa, dummy veri kullan
        final dummyData = await getDummyFoodData();
        return dummyData;
      }
      
      print('En yüksek olasilikli yemek: $predictedFoodName (Olasilik: $highestProbability)');
      
      // Yerel JSON dosyasından yemek verilerini yükle
      final foodData = await _loadFoodData();
      
      // En iyi eşleşmeyi bul
      Map<String, dynamic>? bestMatch;
      double bestSimilarity = 0.0;
      
      for (final food in foodData) {
        final String label = food['label'] ?? '';
        final double similarity = _calculateSimilarity(label, predictedFoodName);
        
        if (similarity > bestSimilarity) {
          bestSimilarity = similarity;
          bestMatch = food;
        }
      }
      
      // Eşleşme bulundu mu kontrol et (benzerlik skoru 0.5'ten büyükse kabul et)
      if (bestMatch != null && bestSimilarity > 0.5) {
        print('JSON dosyasında eşleşen yemek bulundu: ${bestMatch['label']} (Benzerlik: $bestSimilarity)');
        
        // Render API'den gelen tahmin olasılığını ekle ve yemek bilgilerini döndür
        final result = {
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
          'foodName': bestMatch['label'],
          'calories': bestMatch['calories'] ?? 0,
          'carbs': bestMatch['carbohydrates'] ?? 0,
          'protein': bestMatch['protein'] ?? 0,
          'fat': bestMatch['fats'] ?? 0,
          'fiber': bestMatch['fiber'] ?? 0,
          'sugar': bestMatch['sugars'] ?? 0,
          'serving': '${bestMatch['weight'] ?? 100}g',
          'servingAmount': '1',
          'servingUnit': 'porsiyon',
          'brand': '',
          'addedTime': DateTime.now().toIso8601String(),
          'predictionProbability': highestProbability,
          'predictionSource': 'Render API + Yerel JSON',
          'similarityScore': bestSimilarity
        };
        
        return result;
      } else {
        print('JSON dosyasında eşleşen yemek bulunamadı, Render API sonucu kullanılıyor');
        
        // Hiçbir eşleşme bulunamadıysa, Render API sonucunu kullan
        final foodItem = convertToFoodItem(renderResult);
        foodItem['predictionProbability'] = highestProbability;
        foodItem['predictionSource'] = 'Render API (eşleşme yok)';
        
        return foodItem;
      }
    } catch (e, stackTrace) {
      // Hata durumunda
      await ErrorService().logError(e, stackTrace, context: 'recognizeAndMatchWithLocalData');
      print('Yemek tanıma ve eşleştirme hatası: $e');
      
      // Hata durumunda dummy veri döndür
      final dummyData = await getDummyFoodData();
      dummyData['predictionError'] = e.toString();
      return dummyData;
    }
  }
  
  /// Eski Firestore metodu - uyumluluk için bırakıldı, artık yerel JSON kullanıyor
  static Future<Map<String, dynamic>> recognizeAndMatchWithFirestore(Uint8List imageBytes, String fileName) async {
    // Artık yerel JSON kullanıyoruz, bu metod sadece uyumluluk için kalıyor
    return await recognizeAndMatchWithLocalData(imageBytes, fileName);
  }
}