import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:calorie_tracker/services/upload_data.dart'; // Dosyanın yolu doğru olmalı
import 'package:calorie_tracker/services/error_service.dart';
import 'screens/login_screen.dart';
import 'screens/error_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Global hata yakalama fonksiyonu
Future<void> _handleError(FlutterErrorDetails details) async {
  // Hata servisine hata bilgisini gönder
  await ErrorService().logError(
    details.exception,
    details.stack,
    context: 'Global error handler',
  );
}

Future<void> main() async {
  // Global hata yakalama mekanizmasını ayarla
  FlutterError.onError = _handleError;
  
  // Zone ile tüm asenkron hataları yakala
  runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await dotenv.load(fileName: ".env");

    try {
      await Firebase.initializeApp(
        options: FirebaseOptions(
          apiKey: dotenv.env['FIREBASE_API_KEY']!,
          authDomain: dotenv.env['FIREBASE_AUTH_DOMAIN']!,
          databaseURL: dotenv.env['FIREBASE_DATABASE_URL']!,
          projectId: dotenv.env['FIREBASE_PROJECT_ID']!,
          storageBucket: dotenv.env['FIREBASE_STORAGE_BUCKET']!,
          messagingSenderId: dotenv.env['FIREBASE_MESSAGING_SENDER_ID']!,
          appId: dotenv.env['FIREBASE_APP_ID']!,
          measurementId: dotenv.env['FIREBASE_MEASUREMENT_ID']!,
        ),
      );
      
    } catch (e, stackTrace) {
      await ErrorService().logError(e, stackTrace, context: 'Firebase initialization');
      // Hata durumunda kullanıcıya gösterilecek bir mesaj eklenebilir
      debugPrint('Firebase başlatılamadı: $e');
    }

    runApp(const MyApp());
  }, (error, stackTrace) async {
    // Zone içinde yakalanan hataları işle
    await ErrorService().logError(error, stackTrace, context: 'Zone error');
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kalori Takip',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: Colors.green[50],
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
        ),
      ),
      // Rota oluşturma sırasında hata yakalama
      onGenerateRoute: (settings) {
        // Rota oluşturma sırasında oluşabilecek hataları yakala
        try {
          // Normal rota işleme mantığı
          return null; // Varsayılan rota işlemeye devam et
        } catch (e, stackTrace) {
          ErrorService().logError(e, stackTrace, context: 'Route generation');
          return MaterialPageRoute(
            builder: (context) => const ErrorScreen(message: 'Sayfa yüklenirken bir hata oluştu'),
          );
        }
      },
      // Hata widget'ı için builder
      builder: (context, child) {
        return MediaQuery(
          // Sistem metin ölçeğini sabitle (kullanıcı ayarlarından etkilenmesin)
          data: MediaQuery.of(context).copyWith(textScaleFactor: 1.0),
          child: child!,
        );
      },
      home: const LoginScreen(),
    );
  }
}
