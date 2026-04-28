import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'reports_screen.dart';
import 'setting_screen.dart';
import 'camera_screen.dart';
import 'package:calorie_tracker/services/error_service.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    HomeContent(),
    CameraScreen(),
    ReportsScreen(),
  ];

  bool _isContainerVisible = false;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kalori Takip', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          _pages[_selectedIndex], // Seçili sayfayı göster
          Align(
            alignment: Alignment.bottomRight,
            child: AnimatedSwitcher(
              duration: Duration(milliseconds: 300),
              child: _isContainerVisible
                  ? Container(
                key: ValueKey("chatbotContainer"),
                width: 300,
                height: 400,
                margin: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blueGrey[50],
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(Icons.android, size: 50, color: Colors.blue), // Chatbot simgesi
                    const SizedBox(height: 16),
                    Expanded(
                      child: _ChatbotWidget(),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _isContainerVisible = false;
                        });
                      },
                      child: Text("Kapat"),
                    ),
                  ],
                ),
              )
                  : SizedBox.shrink(),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Ana Sayfa',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.camera_alt),
            label: 'Kamera',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Raporlar',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            _isContainerVisible = !_isContainerVisible;
          });
        },
        child: Icon(Icons.android, size: 30), // Android simgesi
      ),
    );
  }
}

class HomeContent extends StatefulWidget {
  @override
  _HomeContentState createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  bool _isLoading = false;

  Future<void> _addFood(Map<String, dynamic> food, String mealType, int weight) async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Calculate nutrients based on weight
        double caloriesPer100g = food['calories'] / 100;
        double carbsPer100g = (food['carbohydrates'] ?? 0) / 100;
        double fatPer100g = (food['fats'] ?? 0) / 100;
        double proteinPer100g = (food['protein'] ?? 0) / 100;

        double selectedCalories = (caloriesPer100g * weight).roundToDouble();
        double selectedCarbs = (carbsPer100g * weight).roundToDouble();
        double selectedFat = (fatPer100g * weight).roundToDouble();
        double selectedProtein = (proteinPer100g * weight).roundToDouble();
        
        // Format date as 'yyyy-MM-dd'
        String date = DateFormat('yyyy-MM-dd').format(DateTime.now());

        await FirebaseFirestore.instance.collection('user_foods').add({
          'userId': user.uid,
          'date': date,
          'foodName': food['label'],
          'calories': selectedCalories,
          'carbs': selectedCarbs,
          'fat': selectedFat,
          'protein': selectedProtein,
          'mealType': mealType,
          'timestamp': FieldValue.serverTimestamp(),
          'weight': weight.toDouble(),
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${food['label']} eklendi')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Stream<List<Map<String, dynamic>>> _getFoodsByMealType(String mealType) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value([]);

    DateTime now = DateTime.now();
    DateTime todayStart = DateTime(now.year, now.month, now.day); 

    return FirebaseFirestore.instance
        .collection('user_foods')
        .where('userId', isEqualTo: user.uid)
        .where('mealType', isEqualTo: mealType)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList();
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildMealCard("Kahvaltı", Icons.wb_sunny, Colors.amber),
          _buildMealCard("Öğle Yemeği", Icons.lunch_dining, Colors.blue),
          _buildMealCard("Akşam Yemeği", Icons.dinner_dining, Colors.orange),
          _buildMealCard("Aperatifler/Diğer", Icons.fastfood, Colors.purple),
        ],
      ),
    );
  }

  Widget _buildMealCard(String title, IconData icon, Color color) {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: color.withOpacity(0.2),
              child: Icon(icon, color: color),
            ),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            trailing: IconButton(
              icon: const Icon(Icons.add, color: Colors.green),
              onPressed: () => _showFoodDialog(title),
            ),
          ),
          ExpansionTile(
            title: const Text("Yemekler"),
            children: [
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: _getFoodsByMealType(title),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text("Hata: ${snapshot.error}"));
                  }
                  final foods = snapshot.data ?? [];
                  if (foods.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text("Henüz eklenen bir yemek yok."),
                    );
                  }
                  return Column(
                    children: foods.asMap().entries.map((entry) {
                      final int index = entry.key;
                      final food = entry.value;
                      return Column(
                        children: [
                          ListTile(
                            title: Text("${food['foodName']}"),
                            subtitle: Text("${food['calories']} kalori"),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
                                try {
                                  await FirebaseFirestore.instance
                                      .collection('user_foods')
                                      .doc(food['id'])
                                      .delete();
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text("${food['foodName']} silindi")),
                                    );
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text("Hata: Yemek silinemedi - ${e.toString()}")),
                                    );
                                  }
                                }
                              },
                            ),
                          ),
                          if (index < foods.length - 1) const Divider(thickness: 1, color: Colors.grey),
                        ],
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeightButton(Map<String, dynamic> food, String mealType, int weight, BuildContext context) {
    double caloriesPer100g = food['calories'] / 100;
    int calculatedCalories = (caloriesPer100g * weight).round();
    
    return ElevatedButton(
      onPressed: () {
        _addFood(food, mealType, weight);
        Navigator.of(context).pop();
        Navigator.of(context).pop();
      },
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text('${weight}g\n${calculatedCalories} kcal', 
        style: const TextStyle(fontSize: 10), 
        textAlign: TextAlign.center
      ),
    );
  }

  Future<void> _showFoodDialog(String mealType) async {
    final searchController = TextEditingController();
    List<Map<String, dynamic>> allFoods = [];
    List<Map<String, dynamic>> filteredFoods = [];
    
    // Load food data from local JSON
    try {
      String jsonString = await rootBundle.loadString('assets/food_and_calories.json');
      List<dynamic> jsonData = jsonDecode(jsonString);
      allFoods = List<Map<String, dynamic>>.from(jsonData);
      print('Loaded ${allFoods.length} food items from JSON');
    } catch (e) {
      print('Error loading food data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Yemek verileri yüklenemedi: $e')),
      );
      return;
    }
    
    // Show dialog
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            void searchFood(String query) {
              setState(() {
                if (query.isEmpty) {
                  filteredFoods = [];
                } else {
                  filteredFoods = allFoods
                      .where((food) => 
                          food['label'].toString().toLowerCase().contains(query.toLowerCase()))
                      .toList();
                  print('Found ${filteredFoods.length} foods for query: $query');
                }
              });
            }
            
            return AlertDialog(
              title: Text("$mealType Seç"),
              content: Container(
                width: double.maxFinite,
                height: 400,
                child: Column(
                  children: [
                    TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        labelText: "Yemek Ara",
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: searchFood,
                    ),
                    SizedBox(height: 10),
                    Expanded(
                      child: filteredFoods.isEmpty
                          ? Center(child: Text(searchController.text.isEmpty 
                              ? "Aramak için bir şeyler yazın" 
                              : "Sonuç bulunamadı"))
                          : ListView.builder(
                              itemCount: filteredFoods.length,
                              itemBuilder: (context, index) {
                                final food = filteredFoods[index];
                                return ListTile(
                                  title: Text(food['label']),
                                  subtitle: Text("${food['calories']} kcal (100g)"),
                                  onTap: () {
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: Text("${food['label']} - Miktar Seç"),
                                        content: Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: [
                                            _buildWeightButton(food, mealType, 50, context),
                                            _buildWeightButton(food, mealType, 100, context),
                                            _buildWeightButton(food, mealType, 150, context),
                                            _buildWeightButton(food, mealType, 200, context),
                                            _buildWeightButton(food, mealType, 250, context),
                                            _buildWeightButton(food, mealType, 300, context),
                                            _buildWeightButton(food, mealType, 350, context),
                                            _buildWeightButton(food, mealType, 400, context),
                                          ],
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context),
                                            child: Text("İptal"),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("İptal"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/');
    }
  }
}

class _ChatbotWidget extends StatefulWidget {
  @override
  __ChatbotWidgetState createState() => __ChatbotWidgetState();
}

class __ChatbotWidgetState extends State<_ChatbotWidget> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Helper method to fix encoding issues with Turkish characters
  String _cleanTurkishText(String text) {
    // First try a direct replacement of common problematic patterns
    Map<String, String> directReplacements = {
      'saÄlıklı': 'sağlıklı',
      'saÄlık': 'sağlık',
      'yaÅam': 'yaşam',
      'konuÅan': 'konuşan',
      'yardÄ±mcÄ±': 'yardımcı',
      'KullanÄ±cÄ±lara': 'Kullanıcılara',
      'uzmanÄ±yÄ±m': 'uzmanıyım',
      'Ã¼': 'ü',
      'Ã¶': 'ö',
      'Ã§': 'ç',
      'Ä±': 'ı',
      'ÄŸ': 'ğ',
      'Å': 'ş',
      'Ã‡': 'Ç',
      'Ã–': 'Ö',
      'Åž': 'Ş',
      'Ä°': 'İ',
      'Ãœ': 'Ü',
      'ÄŸ': 'ğ',
    };
    
    // Apply direct replacements
    String result = text;
    directReplacements.forEach((key, value) {
      result = result.replaceAll(key, value);
    });
    
    // Character by character replacement for any remaining issues
    // This is a more comprehensive approach for any characters we missed
    Map<String, String> turkishChars = {
      'ı': 'ı', 'İ': 'İ', 'ş': 'ş', 'Ş': 'Ş', 'ğ': 'ğ', 'Ğ': 'Ğ',
      'ü': 'ü', 'Ü': 'Ü', 'ö': 'ö', 'Ö': 'Ö', 'ç': 'ç', 'Ç': 'Ç'
    };
    
    // Replace any remaining problematic words
    if (result.contains('saÄ')) {
      result = result.replaceAll('saÄ', 'sağ');
    }
    
    if (result.contains('yaÅ')) {
      result = result.replaceAll('yaÅ', 'yaş');
    }
    
    // Final cleanup for any remaining issues
    result = result.replaceAll('Ä', 'ğ');
    result = result.replaceAll('Å', 'ş');
    
    return result;
  }

  Future<void> sendMessage(String message) async {
    if (message.trim().isEmpty) return;
    
    // Log user message to console
    print("Kullanıcı mesajı: $message");
    
    setState(() {
      _messages.insert(0, {"role": "user", "content": message});
      _isLoading = true;
    });

    try {
      // Use the appropriate server URL based on platform
      String serverUrl = kIsWeb 
          ? "http://localhost:8000/chatbot"  // Use localhost for web
          : "http://10.0.2.2:8000/chatbot";   // For Android emulator
      
      // Create request headers
      Map<String, String> headers = {
        'Content-Type': 'application/json; charset=utf-8',
        'Accept': 'application/json; charset=utf-8',
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
        // Use UTF-8 decoder explicitly to handle the response
        final responseBody = utf8.decode(response.bodyBytes);
        final responseData = jsonDecode(responseBody);
        String botReply = responseData["reply"];
        
        // Extract text within quotes if it's a code snippet
        if (botReply.contains("def ") || botReply.contains("```")) {
          // First try double quotes
          RegExp doubleQuoteRegex = RegExp(r'"([^"]*)"');
          final doubleQuoteMatches = doubleQuoteRegex.allMatches(botReply);
          
          // Then try single quotes
          RegExp singleQuoteRegex = RegExp(r"'([^']*)'");
          final singleQuoteMatches = singleQuoteRegex.allMatches(botReply);
          
          List<String> quotedTexts = [];
          
          // Process double quotes
          for (final match in doubleQuoteMatches) {
            if (match.group(1) != null && match.group(1)!.isNotEmpty) {
              quotedTexts.add(match.group(1)!);
            }
          }
          
          // Process single quotes
          for (final match in singleQuoteMatches) {
            if (match.group(1) != null && match.group(1)!.isNotEmpty) {
              quotedTexts.add(match.group(1)!);
            }
          }
          
          if (quotedTexts.isNotEmpty) {
            botReply = quotedTexts.join(" ");
          } else {
            // If no quotes found, try to clean up the code
            botReply = botReply.replaceAll(RegExp(r'def .*?\(.*?\):'), '');
            botReply = botReply.replaceAll(RegExp(r'return '), '');
            botReply = botReply.replaceAll(RegExp(r'print\(.*?\)'), '');
            // Remove code blocks formatting
            botReply = botReply.replaceAll(RegExp(r'```[\w]*\n'), '');
            botReply = botReply.replaceAll('```', '');
          }
        }
        
        // Clean up any remaining encoding issues
        botReply = _cleanTurkishText(botReply);
        
        print("Chatbot cevabı: $botReply");
        setState(() {
          _messages.insert(0, {"role": "bot", "content": botReply});
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
      
      final errorResponse = "$errorMessage\n\nTeknik detay: $e";
      print("Chatbot hatası: $errorResponse");
      
      setState(() {
        _messages.insert(0, {"role": "bot", "content": errorResponse});
        _isLoading = false;
      });
    }

    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
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
              reverse: true,
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['role'] == 'user';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    padding: EdgeInsets.all(12),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.blue[100] : Colors.green[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(msg['content'] ?? ''),
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
                  decoration: InputDecoration(
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
    );
  }
}