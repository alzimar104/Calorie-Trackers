import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({Key? key}) : super(key: key);

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = [];
  bool _isLoading = false;

  Future<void> sendMessage(String message) async {
    if (message.trim().isEmpty) return;
    
    setState(() {
      _messages.add({"role": "user", "text": message});
      _isLoading = true;
    });

    try {
      // Use the appropriate server URL based on platform
      String serverUrl = kIsWeb 
          ? "http://localhost:8000/chatbot"  // Use localhost for web
          : "http://10.0.2.2:8000/chatbot";   // For Android emulator
      
      // Create request headers
      Map<String, String> headers = {
        'Content-Type': 'application/json',
      };
      
      // Add CORS headers for web
      if (kIsWeb) {
        headers.addAll({
          "Access-Control-Allow-Origin": "*",
          "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
          "Access-Control-Allow-Headers": "Origin, Content-Type, Accept",
        });
      }

      final response = await http.post(
        Uri.parse(serverUrl),
        headers: headers,
        body: jsonEncode({"message": message}),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        setState(() {
          _messages.add({"role": "bot", "text": responseData["reply"]});
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to get response: ${response.statusCode}');
      }
    } catch (e) {
      String errorMessage = "Üzgünüm, bir hata oluştu";
      
      // Provide more helpful error messages
      if (e.toString().contains("Failed to fetch") || 
          e.toString().contains("Connection refused") ||
          e.toString().contains("Connection timed out")) {
        errorMessage = "Sunucuya bağlanılamadı. Lütfen backend sunucusunun çalıştığından emin olun.";
      } else if (e.toString().contains("404")) {
        errorMessage = "API endpoint bulunamadı. Backend yapılandırmasını kontrol edin.";
      }
      
      setState(() {
        _messages.add({"role": "bot", "text": "$errorMessage\n\nTeknik detay: $e"});
        _isLoading = false;
      });
      print("Chatbot error: $e");
    }

    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Sağlık Chatbot")),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty 
            ? Center(
                child: Text(
                  "Sağlık ve beslenme hakkında sorularınızı sorun!",
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              )
            : ListView.builder(
                itemCount: _messages.length,
                reverse: true,
                itemBuilder: (_, index) {
                  final msg = _messages[_messages.length - 1 - index];
                  final isUser = msg["role"] == "user";
                  return Align(
                    alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                      padding: const EdgeInsets.all(12),
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
                      decoration: BoxDecoration(
                        color: isUser ? Colors.blue[100] : Colors.green[100],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(msg["text"] ?? ""),
                    ),
                  );
                },
              ),
          ),
          Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: "Mesajınızı yazın",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(10)),
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onSubmitted: (text) => sendMessage(text),
                  ),
                ),
                SizedBox(width: 8),
                _isLoading
                  ? CircularProgressIndicator()
                  : IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: () => sendMessage(_controller.text),
                    ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
