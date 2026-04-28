import 'package:flutter/material.dart';

/// Hata durumlarında gösterilecek ekran
class ErrorScreen extends StatelessWidget {
  final String message;
  
  const ErrorScreen({
    Key? key, 
    this.message = 'Bir hata oluştu. Lütfen daha sonra tekrar deneyin.'
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hata'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // Önceki sayfaya dön
            Navigator.of(context).pop();
          },
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 80,
              ),
              const SizedBox(height: 20),
              Text(
                message,
                style: const TextStyle(fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () {
                  // Ana sayfaya dön
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                child: const Text('Ana Sayfaya Dön'),
              ),
              const SizedBox(height: 15),
              TextButton(
                onPressed: () {
                  // Sayfayı yeniden yükle
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => ErrorScreen(message: message),
                    ),
                  );
                },
                child: const Text('Yeniden Dene'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
