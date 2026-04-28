import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:calorie_tracker/services/food_recognition_service.dart';
import 'package:calorie_tracker/services/error_service.dart';
import 'package:calorie_tracker/services/barcode_service.dart';
import 'package:calorie_tracker/components/barcode_scanner_view.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({Key? key}) : super(key: key);

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver {
  final ImagePicker _picker = ImagePicker();
  XFile? _pickedImage;
  Uint8List? _imageBytes;
  bool _isProcessing = false;
  bool _isUploading = false;
  double _processingProgress = 0.0;
  Map<String, dynamic>? _recognizedFood;
  String _selectedMealType = 'Öğle Yemeği'; // Default meal type
  String _errorMessage = '';
  
  // Text editing controllers for editable fields
  final TextEditingController _caloriesController = TextEditingController();
  final TextEditingController _carbsController = TextEditingController();
  final TextEditingController _proteinController = TextEditingController();
  final TextEditingController _fatController = TextEditingController();
  final TextEditingController _foodNameController = TextEditingController();
  
  final List<String> _mealTypes = [
    'Kahvaltı',
    'Öğle Yemeği',
    'Akşam Yemeği',
    'Aperatifler/Diğer',
  ];
  
  // Recently added foods for quick selection
  List<Map<String, dynamic>> _recentFoods = [];
  bool _showRecentFoods = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadRecentFoods();
    _loadLastUsedMealType();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _caloriesController.dispose();
    _carbsController.dispose();
    _proteinController.dispose();
    _fatController.dispose();
    _foodNameController.dispose();
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Reset camera when app comes to foreground
    if (state == AppLifecycleState.resumed && _pickedImage == null) {
      // Optional: re-initialize camera if needed
    }
  }
  
  // Load recently added foods from shared preferences
  Future<void> _loadRecentFoods() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recentFoodsJson = prefs.getString('recent_foods');
      if (recentFoodsJson != null) {
        final List<dynamic> decoded = jsonDecode(recentFoodsJson);
        setState(() {
          _recentFoods = decoded.cast<Map<String, dynamic>>();
        });
      }
    } catch (e) {
      print('Error loading recent foods: $e');
    }
  }
  
  // Save recently added food to shared preferences
  Future<void> _saveRecentFood(Map<String, dynamic> food) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Add new food at the beginning and keep only last 10
      _recentFoods.insert(0, food);
      if (_recentFoods.length > 10) {
        _recentFoods = _recentFoods.sublist(0, 10);
      }
      await prefs.setString('recent_foods', jsonEncode(_recentFoods));
    } catch (e) {
      print('Error saving recent food: $e');
    }
  }
  
  // Remember last used meal type
  Future<void> _loadLastUsedMealType() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedMealType = prefs.getString('last_meal_type');
      if (savedMealType != null && _mealTypes.contains(savedMealType)) {
        setState(() {
          _selectedMealType = savedMealType;
        });
      }
    } catch (e) {
      print('Error loading meal type: $e');
    }
  }
  
  Future<void> _saveMealType(String mealType) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_meal_type', mealType);
    } catch (e) {
      print('Error saving meal type: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(), // Dismiss keyboard on tap
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 16),
                _buildImageSection(),
                const SizedBox(height: 16),
                _buildCameraButtons(),
                const SizedBox(height: 16),
                if (_errorMessage.isNotEmpty) _buildErrorMessage(),
                if (_isProcessing) _buildProcessingIndicator(),
                if (_recognizedFood != null) _buildRecognitionResults(),
                if (_showRecentFoods && _recentFoods.isNotEmpty) _buildRecentFoods(),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: _imageBytes == null ? FloatingActionButton(
        onPressed: () {
          setState(() {
            _showRecentFoods = !_showRecentFoods;
          });
        },
        child: Icon(_showRecentFoods ? Icons.history_toggle_off : Icons.history),
        tooltip: 'Son eklenen yemekler',
      ) : null,
    );
  }

  Widget _buildImageSection() {
    return GestureDetector(
      onTap: _pickImage, // Tap on image area to select from gallery
      child: Container(
        width: double.infinity,
        height: 300,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[300]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: _imageBytes != null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.memory(
                      _imageBytes!,
                      fit: BoxFit.cover,
                    ),
                  ),
                  // Reset button
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () {
                          setState(() {
                            _pickedImage = null;
                            _imageBytes = null;
                            _recognizedFood = null;
                            _errorMessage = '';
                          });
                        },
                      ),
                    ),
                  ),
                ],
              )
            : Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.camera_alt, size: 64, color: Colors.grey[600]),
                    const SizedBox(height: 16),
                    Text(
                      'Yemek fotoğrafı çekmek veya\ngaleriden seçmek için dokunun',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildCameraButtons() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.camera_alt),
                label: const Text('Fotoğraf Çek'),
                onPressed: _takePhoto,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.photo_library),
                label: const Text('Galeriden Seç'),
                onPressed: _pickImage,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          icon: const Icon(Icons.qr_code_scanner),
          label: const Text('Barkod ile Bul'),
          onPressed: _scanBarcode,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            backgroundColor: Colors.deepOrange,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
  
  // Barkod tarama fonksiyonu
  void _scanBarcode() {
    setState(() {
      _errorMessage = '';
    });
    
    // Barkod tarayıcıyı tam ekran göster
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => Scaffold(
          body: BarcodeScannerView(
            onBarcodeDetected: (barcode) {
              // Barkod tarayıcıyı kapat
              Navigator.of(context).pop();
              // Barkod ile ürün bilgisini getir
              _getProductByBarcode(barcode);
            },
            onClose: () => Navigator.of(context).pop(),
          ),
        ),
      ),
    );
  }
  
  // Barkod ile ürün bilgisini getir
  Future<void> _getProductByBarcode(String barcode) async {
    setState(() {
      _isProcessing = true;
      _processingProgress = 0.0;
      _errorMessage = '';
    });
    
    try {
      // Barkod API'sinden ürün bilgisini al
      final productInfo = await BarcodeService.getProductByBarcode(barcode);
      
      setState(() {
        _isProcessing = false;
        _recognizedFood = productInfo;
        
        // Besin değerlerini text controller'lara aktar
        _foodNameController.text = productInfo['foodName'] ?? '';
        _caloriesController.text = productInfo['calories']?.toString() ?? '';
        _carbsController.text = productInfo['carbs']?.toString() ?? '';
        _proteinController.text = productInfo['protein']?.toString() ?? '';
        _fatController.text = productInfo['fat']?.toString() ?? '';
      });
    } catch (e, stackTrace) {
      setState(() {
        _isProcessing = false;
        _errorMessage = 'Barkod ile ürün bulunamadı: $e';
      });
      ErrorService().logError(e, stackTrace, context: 'barcode_lookup_error');
    }
  }
  
  Widget _buildErrorMessage() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage,
              style: const TextStyle(color: Colors.red),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.red),
            onPressed: () {
              setState(() {
                _errorMessage = '';
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProcessingIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          LinearProgressIndicator(
            value: _processingProgress > 0 ? _processingProgress : null,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
          ),
          const SizedBox(height: 16),
          Text(
            _isUploading ? 'Fotoğraf yükleniyor...' : 'Yemek tanınıyor...',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _isUploading 
                ? 'Bu işlem internet bağlantınıza bağlı olarak biraz zaman alabilir.'
                : 'Yapay zeka ile yemeğiniz analiz ediliyor.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildRecognitionResults() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildEditableTextField(
              controller: _foodNameController,
              label: 'Yemek Adı',
              fontSize: 24.0,
              fontWeight: FontWeight.bold,
            ),
            const SizedBox(height: 16),
            _buildEditableNutritionInfo(),
            const SizedBox(height: 24),
            _buildMealTypeSelector(),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: _addFoodToMeal,
                child: _isUploading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Yemeği Ekle'),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildEditableTextField({
    required TextEditingController controller,
    required String label,
    double fontSize = 16.0,
    FontWeight fontWeight = FontWeight.normal,
    TextInputType keyboardType = TextInputType.text,
    String? suffix,
  }) {
    return TextField(
      controller: controller,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
      ),
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      keyboardType: keyboardType,
    );
  }

  Widget _buildEditableNutritionInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Besin Değerleri',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildEditableTextField(
                  controller: _caloriesController,
                  label: 'Kalori',
                  keyboardType: TextInputType.number,
                  suffix: 'kcal',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildEditableTextField(
                  controller: _carbsController,
                  label: 'Karbonhidrat',
                  keyboardType: TextInputType.number,
                  suffix: 'g',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildEditableTextField(
                  controller: _proteinController,
                  label: 'Protein',
                  keyboardType: TextInputType.number,
                  suffix: 'g',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildEditableTextField(
                  controller: _fatController,
                  label: 'Yağ',
                  keyboardType: TextInputType.number,
                  suffix: 'g',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMealTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Öğün Tipi',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: _selectedMealType,
              items: _mealTypes.map((String type) {
                return DropdownMenuItem<String>(
                  value: type,
                  child: Text(type),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedMealType = newValue;
                    _saveMealType(newValue);
                  });
                }
              },
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildRecentFoods() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Son Eklenenler',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _showRecentFoods = false;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _recentFoods.length,
            itemBuilder: (context, index) {
              final food = _recentFoods[index];
              return Card(
                elevation: 1,
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(food['name'] ?? food['foodName'] ?? 'İsimsiz Yemek'),
                  subtitle: Text('${food['calories']} kcal'),
                  trailing: Text(food['mealType'] ?? ''),
                  onTap: () {
                    _selectRecentFood(food);
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _takePhoto() async {
    try {
  final XFile? photo = await _picker.pickImage(
    source: ImageSource.camera,
    maxWidth: 1200,
    maxHeight: 1200,
    imageQuality: 85,
  );
  _processPickedImage(photo);
} catch (e, stackTrace) {
  setState(() {
    _errorMessage = 'Kamera erişiminde bir hata oluştu: $e';
  });
  ErrorService().logError(e, stackTrace, context: 'camera_access_error');
}
  }

  Future<void> _pickImage() async {
    try {
  final XFile? image = await _picker.pickImage(
    source: ImageSource.gallery,
    maxWidth: 1200,
    maxHeight: 1200,
    imageQuality: 85,
  );
  _processPickedImage(image);
} catch (e, stackTrace) {
  setState(() {
    _errorMessage = 'Galeri erişiminde bir hata oluştu: $e';
  });
  ErrorService().logError(e, stackTrace, context: 'gallery_access_error');
}
  }



// _processPickedImage metodundaki değişiklikler:
Future<void> _processPickedImage(XFile? image) async {
  if (image == null) return;
  
  setState(() {
    _pickedImage = image;
    _isProcessing = true;
    _errorMessage = '';
    _isUploading = true;
  });
  
  try {
    // Read image bytes
    final bytes = await image.readAsBytes();
    
    setState(() {
      _imageBytes = bytes;
    });

    // Simulate upload progress
    for (int i = 1; i <= 10; i++) {
      await Future.delayed(const Duration(milliseconds: 200));
      setState(() {
        _processingProgress = i / 10;
      });
    }

    setState(() {
      _isUploading = false;
      _processingProgress = 0.0;
    });

    // Process the image with the food recognition service and match with local JSON data
    // Render'daki yemek tanıma projesi ile yerel JSON dosyası entegrasyonu
    final result = await FoodRecognitionService.recognizeAndMatchWithLocalData(bytes, image.name);
    
    // Update controllers with the recognized food information
    _foodNameController.text = result['foodName'] ?? '';
    _caloriesController.text = result['calories']?.toString() ?? '';
    _carbsController.text = result['carbs']?.toString() ?? '';
    _proteinController.text = result['protein']?.toString() ?? '';
    _fatController.text = result['fat']?.toString() ?? '';

    // Show prediction source if available
    String statusMessage = '';
    if (result.containsKey('predictionSource')) {
      statusMessage = 'Kaynak: ${result['predictionSource']}';
      if (result.containsKey('predictionProbability')) {
        final probability = (result['predictionProbability'] * 100).toStringAsFixed(1);
        statusMessage += ' (Güven: %$probability)';
      }
    }
    
    setState(() {
      _recognizedFood = result;
      _isProcessing = false;
      if (statusMessage.isNotEmpty) {
        _errorMessage = statusMessage; // Kullanıcıya tahmin kaynağını göster
      }
    });
  } catch (e, stackTrace) {
    setState(() {
      _isProcessing = false;
      _isUploading = false;
      _errorMessage = 'Yemek tanımada bir sorun oluştu: $e';
    });
    ErrorService().logError(e, stackTrace, context: 'food_recognition_error');
  }
}

  void _selectRecentFood(Map<String, dynamic> food) {
    setState(() {
      _recognizedFood = food;
      _showRecentFoods = false;
      
      // Update controllers - handle both 'name' and 'foodName' keys
      _foodNameController.text = food['name'] ?? food['foodName'] ?? '';
      _caloriesController.text = food['calories']?.toString() ?? '';
      _carbsController.text = food['carbs']?.toString() ?? '';
      _proteinController.text = food['protein']?.toString() ?? '';
      _fatController.text = food['fat']?.toString() ?? '';
      
      // Update meal type if available
      if (food['mealType'] != null && _mealTypes.contains(food['mealType'])) {
        _selectedMealType = food['mealType'];
      }
    });
  }

  Future<void> _addFoodToMeal() async {
    if (_recognizedFood == null) return;
    
    setState(() {
      _isUploading = true;
    });
    
    try {
      // Yemek verilerini hazırla
      final String foodName = _foodNameController.text;
      final double calories = double.tryParse(_caloriesController.text) ?? 0;
      final double carbs = double.tryParse(_carbsController.text) ?? 0;
      final double protein = double.tryParse(_proteinController.text) ?? 0;
      final double fat = double.tryParse(_fatController.text) ?? 0;
      final int weight = 100; // Varsayılan ağırlık
      
      // Format date as 'yyyy-MM-dd'
      String date = DateFormat('yyyy-MM-dd').format(DateTime.now());
      
      // Kullanıcı bilgisini al
      final user = FirebaseAuth.instance.currentUser;
      
      if (user != null) {
        // Firestore'a kaydet
        await FirebaseFirestore.instance.collection('user_foods').add({
          'userId': user.uid,
          'date': date,
          'foodName': foodName,
          'calories': calories,
          'carbs': carbs,
          'fat': fat,
          'protein': protein,
          'mealType': _selectedMealType,
          'timestamp': FieldValue.serverTimestamp(),
          'weight': weight.toDouble(),
        });
        
        // Yerel olarak da kaydet (son eklenenler listesi için)
        final foodData = {
          'name': foodName,
          'foodName': foodName,
          'calories': calories,
          'carbs': carbs,
          'protein': protein,
          'fat': fat,
          'mealType': _selectedMealType,
          'date': date,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'userId': user.uid,
          'weight': weight.toDouble(),
        };
        
        await _saveRecentFood(foodData);
        
        // Kullanıcıya başarı mesajı göster
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$foodName başarıyla eklendi'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Formu sıfırla
        setState(() {
          _pickedImage = null;
          _imageBytes = null;
          _recognizedFood = null;
          _isUploading = false;
        });
        
        // Son eklenen yemekleri yeniden yükle
        await _loadRecentFoods();
        
        // Yeni eklenen yemeğin görünmesi için state'i güncelle
        setState(() {
          _showRecentFoods = true;
        });
      } else {
        // Kullanıcı giriş yapmamışsa hata göster
        setState(() {
          _isUploading = false;
          _errorMessage = 'Yemek eklemek için giriş yapmalısınız';
        });
      }
    } catch (e, stackTrace) {
      setState(() {
        _isUploading = false;
        _errorMessage = 'Yemek eklenirken bir sorun oluştu: $e';
      });
      ErrorService().logError(e, stackTrace, context: 'add_food_error');
    }
  }
}