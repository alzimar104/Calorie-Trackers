import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> uploadJsonToFirestore() async {
  try {
    // JSON dosyasını oku
    String jsonString = await rootBundle.loadString('assets/food_and_calories.json');
    List<dynamic> foodList = jsonDecode(jsonString);

    // Firestore referansı
    CollectionReference foodsCollection = FirebaseFirestore.instance.collection('foods');

    // JSON'daki her öğeyi ekle
    for (var food in foodList) {
      await foodsCollection.add({
        'calories': food['calories'],
        'carbohydrates': food['carbohydrates'],
        'fats': food['fats'],
        'fiber': food['fiber'],
        'foodName': food['label'], // JSON'da "label" ama DB'de "foodName" kullanılıyor
        'protein': food['protein'],
        'sodium': food['sodium'],
        'sugars': food['sugars'],
        'weight': food['weight'],
      });
    }

    print('Veriler Firestore\'a başarıyla yüklendi.');
  } catch (e) {
    print('Hata oluştu: $e');
  }
}
