import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:calorie_tracker/screens/macro_nutrients_screen.dart';
import 'package:calorie_tracker/widgets/daily_nutrition_summary_widget.dart';


class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  Widget _buildDailyNutritionSummary() {
    return DailyNutritionSummary(
      totalCalories: _totalCaloriesToday,
      calorieGoal: _calorieGoal,
      totalCarbs: _totalCarbsToday,
      carbGoal: _carbGoal,
      totalFat: _totalFatToday,
      fatGoal: _fatGoal,
      totalProtein: _totalProteinToday,
      proteinGoal: _proteinGoal,
    );
  }
  
  String _selectedDate = "";
  Map<String, int> _dailyCalories = {};
  Map<String, double> _dailyCarbs = {};
  Map<String, double> _dailyFat = {};
  Map<String, double> _dailyProtein = {};
  
  // Günlük besin değerleri
  int _totalCaloriesToday = 0;
  double _totalCarbsToday = 0;
  double _totalFatToday = 0;
  double _totalProteinToday = 0;
  
  // Hedefler için değişkenler
  int _calorieGoal = 2000;
  double _carbGoal = 250.0;
  double _fatGoal = 70.0;
  double _proteinGoal = 100.0;
  
  bool _isEditingGoal = false;
  final TextEditingController _calorieController = TextEditingController();
  final TextEditingController _carbController = TextEditingController();
  final TextEditingController _fatController = TextEditingController();
  final TextEditingController _proteinController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchNutrientGoals();
  }

  @override
  void dispose() {
    _calorieController.dispose();
    _carbController.dispose();
    _fatController.dispose();
    _proteinController.dispose();
    super.dispose();
  }

  // Kullanıcı verileri ve hedefleri getiren fonksiyon
  Future<void> _fetchUserData() async {
    await _fetchNutrientGoals();
  }

  // Kullanıcının besin hedeflerini getiren fonksiyon
  Future<void> _fetchNutrientGoals() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data() ?? {};
        setState(() {
          _calorieGoal = (data['calorieGoal'] as num?)?.toInt() ?? 2000;
          _carbGoal = (data['carbGoal'] as num?)?.toDouble() ?? 250.0;
          _fatGoal = (data['fatGoal'] as num?)?.toDouble() ?? 70.0;
          _proteinGoal = (data['proteinGoal'] as num?)?.toDouble() ?? 100.0;

          _calorieController.text = _calorieGoal.toString();
          _carbController.text = _carbGoal.toString();
          _fatController.text = _fatGoal.toString();
          _proteinController.text = _proteinGoal.toString();
        });
      }
    } catch (e) {
      print('Besin hedefi getirilirken hata: $e');
    }
  }

  // Besin hedeflerini güncelleyen fonksiyon
  Future<void> _updateNutrientGoals() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final calorie = int.tryParse(_calorieController.text);
      final carb = double.tryParse(_carbController.text);
      final fat = double.tryParse(_fatController.text);
      final protein = double.tryParse(_proteinController.text);

      if (calorie == null || carb == null || fat == null || protein == null ||
          calorie <= 0 || carb <= 0 || fat <= 0 || protein <= 0) {
        throw Exception('Tüm değerler pozitif olmalıdır');
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
            'calorieGoal': calorie,
            'carbGoal': carb,
            'fatGoal': fat,
            'proteinGoal': protein,
          }, SetOptions(merge: true));

      setState(() {
        _calorieGoal = calorie;
        _carbGoal = carb;
        _fatGoal = fat;
        _proteinGoal = protein;
        _isEditingGoal = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Beslenme hedefleri güncellendi')),
      );
    } catch (e) {
      print('Besin hedefleri güncellenirken hata: $e');
      String errorMessage = 'Besin hedefleri güncellenirken bir hata oluştu';

      if (e.toString().contains('pozitif')) {
        errorMessage = 'Tüm değerler pozitif sayı olmalıdır';
      } else if (e.toString().contains('permission-denied')) {
        errorMessage = 'Yetki hatası: Lütfen tekrar giriş yapın';
      } else if (e.toString().contains('network')) {
        errorMessage = 'İnternet bağlantınızı kontrol edin';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    }
  }

  Stream<Map<String, dynamic>> _getDailyNutrientsStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value({});

    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    final startDate = DateFormat('yyyy-MM-dd').format(sevenDaysAgo);
    final endDate = DateFormat('yyyy-MM-dd').format(now);
    final today = DateFormat('yyyy-MM-dd').format(now);

    return FirebaseFirestore.instance
        .collection('user_foods')
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .map((snapshot) {
          Map<String, int> dailyCalories = {};
          Map<String, double> dailyCarbs = {};
          Map<String, double> dailyFat = {};
          Map<String, double> dailyProtein = {};

          int totalCaloriesToday = 0;
          double totalCarbsToday = 0;
          double totalFatToday = 0;
          double totalProteinToday = 0;

          // Tüm tarihleri başlangıçta sıfır değerlerle doldur
          for (int i = 0; i <= 7; i++) {
            final date = now.subtract(Duration(days: i));
            final dateString = DateFormat('yyyy-MM-dd').format(date);
            dailyCalories[dateString] = 0;
            dailyCarbs[dateString] = 0.0;
            dailyFat[dateString] = 0.0;
            dailyProtein[dateString] = 0.0;
          }

          // Tüm yemekleri topla
          for (var doc in snapshot.docs) {
            final data = doc.data();
            // Timestamp'i tarihe çevir veya varsa date alanını kullan
            final dateString = data['date'] as String? ??
                DateFormat('yyyy-MM-dd').format((data['timestamp'] as Timestamp).toDate());

            // Tip dönüşümlerini doğru şekilde yap
            final calories = data['calories'] is String
                ? int.tryParse(data['calories'] as String) ?? 0
                : (data['calories'] as num?)?.toInt() ?? 0;

            final carbs = data['carbs'] is String
                ? double.tryParse(data['carbs'] as String) ?? 0.0
                : (data['carbs'] as num?)?.toDouble() ?? 0.0;

            final fat = data['fat'] is String
                ? double.tryParse(data['fat'] as String) ?? 0.0
                : (data['fat'] as num?)?.toDouble() ?? 0.0;

            final protein = data['protein'] is String
                ? double.tryParse(data['protein'] as String) ?? 0.0
                : (data['protein'] as num?)?.toDouble() ?? 0.0;

            // Günlük toplam veriler
            dailyCalories[dateString] = (dailyCalories[dateString] ?? 0) + calories;
            dailyCarbs[dateString] = (dailyCarbs[dateString] ?? 0.0) + carbs;
            dailyFat[dateString] = (dailyFat[dateString] ?? 0.0) + fat;
            dailyProtein[dateString] = (dailyProtein[dateString] ?? 0.0) + protein;

            // Bugünkü değerler
            if (dateString == today) {
              totalCaloriesToday += calories;
              totalCarbsToday += carbs;
              totalFatToday += fat;
              totalProteinToday += protein;
            }
          }

          return {
            'dailyCalories': dailyCalories,
            'dailyCarbs': dailyCarbs,
            'dailyFat': dailyFat,
            'dailyProtein': dailyProtein,
            'totalCaloriesToday': totalCaloriesToday,
            'totalCarbsToday': totalCarbsToday,
            'totalFatToday': totalFatToday,
            'totalProteinToday': totalProteinToday
          };
        });
  }

  // Grafik gösterimi için son 7 günlük verileri hazırlama
  List<BarChartGroupData> _getCalorieSpots() {
    final List<String> last7Days = [];
    for (int i = 6; i >= 0; i--) {
      final date = DateTime.now().subtract(Duration(days: i));
      last7Days.add(DateFormat('yyyy-MM-dd').format(date));
    }

    final barGroups = <BarChartGroupData>[];
    for (int i = 0; i < last7Days.length; i++) {
      final date = last7Days[i];
      final calories = _dailyCalories[date] ?? 0;

      // Determine bar color based on calorie goal
      final barColor = calories > _calorieGoal ? Colors.red : Colors.green;

      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: calories.toDouble(),
              color: barColor,
              width: 16,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
          ],
        ),
      );
    }
    return barGroups;
  }

  // Son 7 günlük tarihleri bottom title olarak gösterme
  Widget _bottomTitleWidgets(double value, TitleMeta meta) {
    final now = DateTime.now();
    final date = now.subtract(Duration(days: 6 - value.toInt()));
    final text = DateFormat('dd/MM').format(date);

    return Text(
      text, 
      style: TextStyle(fontSize: 10),
    );
  }

  Widget _buildDailyNutrientChart() {
    return Container(
      height: 250,
      padding: const EdgeInsets.all(8),
      child: BarChart(
        BarChartData(
          barGroups: _getCalorieSpots(),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: _bottomTitleWidgets,
                reservedSize: 30,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
              ),
            ),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            show: true,
            drawHorizontalLine: true,
            drawVerticalLine: false,
          ),
          borderData: FlBorderData(show: true),
          // Add target calorie line
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              HorizontalLine(
                y: _calorieGoal.toDouble(),
                color: Colors.blue,
                strokeWidth: 2,
                dashArray: [5, 5],
                label: HorizontalLineLabel(
                  show: true,
                  alignment: Alignment.topRight,
                  padding: const EdgeInsets.only(right: 5, bottom: 5),
                  style: const TextStyle(color: Colors.blue),
                  labelResolver: (line) => 'Hedef: ${_calorieGoal}',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNutrientProgressBar(String label, double current, double goal, Color color) {
    final progress = goal > 0 ? (current / goal).clamp(0.0, 2.0) : 0.0;
    // Determine color based on progress
    final progressColor = progress > 1.0 ? Colors.red : color;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            Text(
              '${current.toStringAsFixed(1)} / ${goal.toStringAsFixed(1)}${label == 'Kalori' ? '' : 'g'}',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey[200],
            color: progressColor,
            minHeight: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildEditGoalsForm() {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Beslenme Hedeflerini Düzenle',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _calorieController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Kalori Hedefi (kcal)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _carbController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Karbonhidrat Hedefi (g)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _fatController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Yağ Hedefi (g)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _proteinController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Protein Hedefi (g)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isEditingGoal = false;
                    });
                  },
                  child: const Text('İptal'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _updateNutrientGoals,
                  child: const Text('Kaydet'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayNutrientSummary() {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.today, color: Colors.green),
                    const SizedBox(width: 8),
                    Text(
                      'Bugünkü Besin Değerleri',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.green),
                  onPressed: () {
                    setState(() {
                      _isEditingGoal = true;
                    });
                  },
                  tooltip: 'Hedefleri Düzenle',
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildNutrientProgressBar('Kalori', _totalCaloriesToday.toDouble(), _calorieGoal.toDouble(), Colors.red),
            const SizedBox(height: 12),
            _buildNutrientProgressBar('Karbonhidrat', _totalCarbsToday, _carbGoal, Colors.blue),
            const SizedBox(height: 12),
            _buildNutrientProgressBar('Yağ', _totalFatToday, _fatGoal, Colors.orange),
            const SizedBox(height: 12),
            _buildNutrientProgressBar('Protein', _totalProteinToday, _proteinGoal, Colors.purple),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyOverview() {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_view_week, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  'Haftalık Kalori Takibi',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildDailyNutrientChart(),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem('Hedef Altı', Colors.green),
                const SizedBox(width: 20),
                _buildLegendItem('Hedef Üstü', Colors.red),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 4),
        Text(label),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Beslenme Raporları"),
        backgroundColor: Colors.green,
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) => const MacroNutrientsScreen(),
                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                    var begin = const Offset(1.0, 0.0);
                    var end = Offset.zero;
                    var curve = Curves.easeInOut;
                    var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                    return SlideTransition(position: animation.drive(tween), child: child);
                  },
                ),
              );
            },
            icon: const Icon(Icons.food_bank, color: Colors.white),
            label: const Text("Makro Besinler", style: TextStyle(color: Colors.white)),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // Refresh the stream by restarting it
          setState(() {
            // Force a rebuild
          });
        },
        child: StreamBuilder<Map<String, dynamic>>(
          stream: _getDailyNutrientsStream(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(child: Text('Hata: ${snapshot.error}'));
            }

            final data = snapshot.data ?? {};

            // Update state with the latest data
            _dailyCalories = data['dailyCalories'] ?? {};
            _dailyCarbs = data['dailyCarbs'] ?? {};
            _dailyFat = data['dailyFat'] ?? {};
            _dailyProtein = data['dailyProtein'] ?? {};
            _totalCaloriesToday = data['totalCaloriesToday'] ?? 0;
            _totalCarbsToday = data['totalCarbsToday'] ?? 0.0;
            _totalFatToday = data['totalFatToday'] ?? 0.0;
            _totalProteinToday = data['totalProteinToday'] ?? 0.0;

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isEditingGoal)
                    _buildEditGoalsForm()
                  else
                    _buildTodayNutrientSummary(),
                  const SizedBox(height: 16),
                  _buildWeeklyOverview(),
                  const SizedBox(height: 16),
                  _buildDailyNutritionSummary(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}