import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

/// Uygulama genelinde hata yönetimi için kullanılan servis
class ErrorService {
  // Singleton pattern
  static final ErrorService _instance = ErrorService._internal();
  factory ErrorService() => _instance;
  ErrorService._internal();

  // Hata mesajlarını kaydetmek için Firestore koleksiyonu
  final CollectionReference _errorLogs = FirebaseFirestore.instance.collection('error_logs');

  /// Genel hata yakalama ve işleme fonksiyonu
  Future<void> logError(dynamic error, StackTrace? stackTrace, {String? context}) async {
    try {
      // Hata tipine göre özelleştirilmiş mesajlar
      String errorMessage = _getErrorMessage(error);
      
      // Konsola hata mesajını yazdır
      debugPrint('ERROR: $errorMessage');
      if (stackTrace != null) {
        debugPrint('STACK TRACE: $stackTrace');
      }
      
      // Kullanıcı oturum açmışsa, hatayı Firestore'a kaydet
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _errorLogs.add({
          'userId': user.uid,
          'errorMessage': errorMessage,
          'stackTrace': stackTrace?.toString(),
          'context': context,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      // Hata kaydı sırasında oluşan hatalar için fallback
      debugPrint('Error logging failed: $e');
    }
  }

  /// Hata tipine göre kullanıcı dostu mesaj döndürür
  String _getErrorMessage(dynamic error) {
    if (error is FirebaseAuthException) {
      return _getFirebaseAuthErrorMessage(error);
    } else if (error is FirebaseException) {
      return _getFirebaseErrorMessage(error);
    } else if (error is http.ClientException) {
      return 'İnternet bağlantınızı kontrol edin.';
    } else if (error is TimeoutException) {
      return 'İstek zaman aşımına uğradı. Lütfen daha sonra tekrar deneyin.';
    } else {
      return error.toString();
    }
  }

  /// Firebase Authentication hatalarını kullanıcı dostu mesajlara çevirir
  String _getFirebaseAuthErrorMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'user-not-found':
        return 'Bu e-posta adresiyle kayıtlı bir kullanıcı bulunamadı.';
      case 'wrong-password':
        return 'Hatalı şifre girdiniz.';
      case 'email-already-in-use':
        return 'Bu e-posta adresi zaten kullanımda.';
      case 'weak-password':
        return 'Şifre çok zayıf. Daha güçlü bir şifre seçin.';
      case 'invalid-email':
        return 'Geçersiz e-posta adresi.';
      case 'user-disabled':
        return 'Bu kullanıcı hesabı devre dışı bırakılmış.';
      case 'too-many-requests':
        return 'Çok fazla başarısız giriş denemesi. Lütfen daha sonra tekrar deneyin.';
      default:
        return 'Kimlik doğrulama hatası: ${error.message}';
    }
  }

  /// Firebase hatalarını kullanıcı dostu mesajlara çevirir
  String _getFirebaseErrorMessage(FirebaseException error) {
    switch (error.code) {
      case 'permission-denied':
        return 'Bu işlem için yetkiniz yok.';
      case 'unavailable':
        return 'Servis şu anda kullanılamıyor. Lütfen daha sonra tekrar deneyin.';
      case 'not-found':
        return 'İstenen veri bulunamadı.';
      default:
        return 'Veritabanı hatası: ${error.message}';
    }
  }

  /// Hata mesajını kullanıcıya göstermek için SnackBar
  static void showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Tamam',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  /// Başarı mesajını kullanıcıya göstermek için SnackBar
  static void showSuccessSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

/// Özel hata sınıfı: Zaman aşımı hataları için
class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);
  
  @override
  String toString() => message;
}
