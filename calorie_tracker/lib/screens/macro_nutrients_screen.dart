import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:pie_chart/pie_chart.dart' as pie;
import 'package:calorie_tracker/widgets/daily_nutrition_summary_widget.dart';

class MacroNutrientsScreen extends StatefulWidget {
  const MacroNutrientsScreen({super.key});

  @override
  State<MacroNutrientsScreen> createState() => _MacroNutrientsScreenState();
}

class _MacroNutrientsScreenState extends State<MacroNutrientsScreen> {
  String _selectedDate = "";
  Map<String, double> _dailyCarbs = {};
  Map<String, double> _dailyFat = {};
  Map<String, double> _dailyProtein = {};
  
  // Günlük besin değerleri
  double _totalCarbsToday = 0;
  double _totalFatToday = 0;
  double _totalProteinToday = 0;
  
  // Hedefler için değişkenler
  double _carbGoal = 250.0;
  double _fatGoal = 70.0;
  double _proteinGoal = 100.0;
  
  // Aktif görünüm seçimi
  String _activeView = 'carbs'; // 'carbs', 'fat', 'protein'

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  // Kullanıcı verileri ve hedefleri getiren fonksiyon
  Future<void> _fetchUserData() async {
    await _fetchNutrientGoals();
    await _fetchDailyNutrients();
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
          _carbGoal = (data['carbGoal'] as num?)?.toDouble() ?? 250.0;
          _fatGoal = (data['fatGoal'] as num?)?.toDouble() ?? 70.0;
          _proteinGoal = (data['proteinGoal'] as num?)?.toDouble() ?? 100.0;
        });
      }
    } catch (e) {
      print('Besin hedefi getirilirken hata: $e');
    }
  }

  Future<void> _fetchDailyNutrients() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('user_foods')
        .where('userId', isEqualTo: user.uid)
        .orderBy('timestamp', descending: false)
        .get();

    Map<String, double> dailyCarbs = {};
    Map<String, double> dailyFat = {};
    Map<String, double> dailyProtein = {};
    
    double totalCarbsToday = 0;
    double totalFatToday = 0;
    double totalProteinToday = 0;
    
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    for (var doc in snapshot.docs) {
      final data = doc.data();
      if (!data.containsKey('timestamp')) continue;

      final timestamp = (data['timestamp'] as Timestamp).toDate();
      final date = DateFormat('yyyy-MM-dd').format(timestamp);
      
      // Besin değerlerini alıyoruz
      final carbs = data['carbs'] is String 
          ? double.tryParse(data['carbs'] as String) ?? 0.0 
          : (data['carbs'] as num?)?.toDouble() ?? 0.0;
          
      final fat = data['fat'] is String 
          ? double.tryParse(data['fat'] as String) ?? 0.0 
          : (data['fat'] as num?)?.toDouble() ?? 0.0;
          
      final protein = data['protein'] is String 
          ? double.tryParse(data['protein'] as String) ?? 0.0 
          : (data['protein'] as num?)?.toDouble() ?? 0.0;

      // Günlük toplam besin değerlerini hesaplıyoruz
      dailyCarbs[date] = (dailyCarbs[date] ?? 0) + carbs;
      dailyFat[date] = (dailyFat[date] ?? 0) + fat;
      dailyProtein[date] = (dailyProtein[date] ?? 0) + protein;

      // Bugünün değerlerini ayrıca tutuyoruz
      if (date == today) {
        totalCarbsToday += carbs;
        totalFatToday += fat;
        totalProteinToday += protein;
      }
    }

    setState(() {
      _dailyCarbs = dailyCarbs;
      _dailyFat = dailyFat;
      _dailyProtein = dailyProtein;
      
      _selectedDate = dailyCarbs.keys.isNotEmpty 
          ? (dailyCarbs.keys.toList()..sort()).last 
          : today;
          
      _totalCarbsToday = totalCarbsToday;
      _totalFatToday = totalFatToday;
      _totalProteinToday = totalProteinToday;
    });
  }
  
 Widget _buildDailyNutritionSummary() {
  return DailyNutritionSummary(
    totalCalories: 0, // Bu değeri sağlamanız gerekiyor
    calorieGoal: 0, // Bu değeri sağlamanız gerekiyor
    totalCarbs: _totalCarbsToday,
    totalFat: _totalFatToday,
    totalProtein: _totalProteinToday,
    carbGoal: _carbGoal,
    fatGoal: _fatGoal,
    proteinGoal: _proteinGoal,
  );
}

  Widget _buildPieChart() {
    // Bugünün besin değerlerini pasta grafiğinde göster
    final dataMap = <String, double>{
      "Karbonhidrat": _totalCarbsToday,
      "Yağ": _totalFatToday,
      "Protein": _totalProteinToday,
    };

    final colorList = <Color>[
      Colors.blue,
      Colors.orange,
      Colors.purple,
    ];

    // Bugünün tarihini al
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final selectedDate = _selectedDate.isEmpty ? today : _selectedDate;
    
    // Tarih seçici için son 7 günü hazırla
    final dates = <String>[];
    final dateLabels = <String>[];
    for (int i = 6; i >= 0; i--) {
      final date = DateTime.now().subtract(Duration(days: i));
      dates.add(DateFormat('yyyy-MM-dd').format(date));
      dateLabels.add(DateFormat('dd MMM').format(date));
    }

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
                Icon(Icons.pie_chart, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  "Makro Besin Dağılımı",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Tarih seçici
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButton<String>(
                value: selectedDate,
                isExpanded: true,
                underline: Container(),
                icon: const Icon(Icons.calendar_today),
                items: List.generate(dates.length, (index) {
                  return DropdownMenuItem<String>(
                    value: dates[index],
                    child: Text(dateLabels[index]),
                  );
                }),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedDate = value;
                    });
                  }
                },
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: pie.PieChart(
                dataMap: dataMap,
                chartType: pie.ChartType.ring,
                colorList: colorList,
                chartRadius: MediaQuery.of(context).size.width / 3,
                centerText: "Makro\nDağılım",
                legendOptions: const pie.LegendOptions(
                  showLegends: true,
                  legendPosition: pie.LegendPosition.bottom,
                  showLegendsInRow: true,
                  legendTextStyle: TextStyle(fontWeight: FontWeight.bold),
                ),
                chartValuesOptions: const pie.ChartValuesOptions(
                  showChartValues: true,
                  showChartValuesInPercentage: true,
                  chartValueStyle: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                ),
                animationDuration: const Duration(milliseconds: 800),
                ringStrokeWidth: 25,
                baseChartColor: Colors.grey[300]!,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBars() {
    // Karbonhidrat, yağ ve protein için ilerleme çubuklarını göster
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
                Icon(Icons.trending_up, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  "Günlük Hedefler",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildProgressBar("Karbonhidrat", _totalCarbsToday, _carbGoal, Colors.blue),
            const SizedBox(height: 12),
            _buildProgressBar("Yağ", _totalFatToday, _fatGoal, Colors.orange),
            const SizedBox(height: 12),
            _buildProgressBar("Protein", _totalProteinToday, _proteinGoal, Colors.purple),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar(String label, double value, double goal, Color color) {
    final progress = goal > 0 ? (value / goal).clamp(0.0, 2.0) : 0.0;
    final percentage = progress * 100;
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
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            Text(
              "${value.toStringAsFixed(1)}g / ${goal.toStringAsFixed(1)}g",
              style: TextStyle(fontWeight: FontWeight.w500),
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
        const SizedBox(height: 2),
        Text(
          "${percentage.toStringAsFixed(1)}%", 
          style: TextStyle(fontSize: 12, color: progressColor, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildTrendChart() {
    // Son 7 günlük tarihleri hazırla
    final today = DateTime.now();
    final dates = List.generate(7, (index) {
      final date = today.subtract(Duration(days: 6 - index));
      return DateFormat('yyyy-MM-dd').format(date);
    });

    // Aktif görünüme göre veri seçimi
    Map<String, double> dataMap;
    String title;
    Color barColor;
    double goalValue;

    switch (_activeView) {
      case 'carbs':
        dataMap = _dailyCarbs;
        title = "Karbonhidrat Grafiği";
        barColor = Colors.blue;
        goalValue = _carbGoal;
        break;
      case 'fat':
        dataMap = _dailyFat;
        title = "Yağ Grafiği";
        barColor = Colors.orange;
        goalValue = _fatGoal;
        break;
      case 'protein':
        dataMap = _dailyProtein;
        title = "Protein Grafiği";
        barColor = Colors.purple;
        goalValue = _proteinGoal;
        break;
      default:
        dataMap = _dailyCarbs;
        title = "Karbonhidrat Grafiği";
        barColor = Colors.blue;
        goalValue = _carbGoal;
    }

    // Bar chart gruplarını oluştur
    final barGroups = <BarChartGroupData>[];
    for (int i = 0; i < dates.length; i++) {
      final value = dataMap[dates[i]] ?? 0.0;
      final isAboveGoal = value > goalValue;
      
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: value,
              color: isAboveGoal ? Colors.red : barColor,
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
                    Icon(Icons.bar_chart, color: Colors.green),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    _buildViewToggleButton('carbs', 'Karbonhidrat', Colors.blue),
                    _buildViewToggleButton('fat', 'Yağ', Colors.orange),
                    _buildViewToggleButton('protein', 'Protein', Colors.purple),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 250,
              child: BarChart(
                BarChartData(
                  barGroups: barGroups,
                  gridData: FlGridData(show: true),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= 0 && value.toInt() < dates.length) {
                            final dateStr = dates[value.toInt()];
                            final date = DateFormat('yyyy-MM-dd').parse(dateStr);
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                DateFormat('dd/MM').format(date),
                                style: const TextStyle(fontSize: 10),
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '${value.toInt()}g',
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: true),
                  // Hedef çizgisi ekle
                  extraLinesData: ExtraLinesData(
                    horizontalLines: [
                      HorizontalLine(
                        y: goalValue,
                        color: Colors.grey,
                        strokeWidth: 2,
                        dashArray: [5, 5],
                        label: HorizontalLineLabel(
                          show: true,
                          alignment: Alignment.topRight,
                          padding: const EdgeInsets.only(right: 5, bottom: 5),
                          style: const TextStyle(color: Colors.grey),
                          labelResolver: (line) => 'Hedef: ${goalValue.toStringAsFixed(1)}g',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem('Hedef Altı', barColor),
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

  Widget _buildViewToggleButton(String view, String label, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: ElevatedButton(
        onPressed: () {
          setState(() {
            _activeView = view;
          });
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: _activeView == view ? color : Colors.grey.shade200,
          foregroundColor: _activeView == view ? Colors.white : Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          minimumSize: const Size(40, 36),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: _activeView == view ? 4 : 0,
        ),
        child: Text(label.substring(0, 3)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Makro Besinler'),
        backgroundColor: Colors.green,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchDailyNutrients,
            tooltip: 'Verileri Yenile',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchDailyNutrients,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTrendChart(),
              const SizedBox(height: 16),
              _buildPieChart(),
              const SizedBox(height: 16),
              _buildProgressBars(),
              const SizedBox(height: 16),
              _buildDailyNutritionSummary(),
            ],
          ),
        ),
      ),
    );
  }
}