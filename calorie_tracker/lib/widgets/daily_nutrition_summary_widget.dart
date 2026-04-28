import 'package:flutter/material.dart';

class DailyNutritionSummary extends StatelessWidget {
  final int totalCalories;
  final int calorieGoal;
  final double totalCarbs;
  final double carbGoal;
  final double totalFat;
  final double fatGoal;
  final double totalProtein;
  final double proteinGoal;

  const DailyNutritionSummary({
    super.key,
    required this.totalCalories,
    required this.calorieGoal,
    required this.totalCarbs,
    required this.carbGoal,
    required this.totalFat,
    required this.fatGoal,
    required this.totalProtein,
    required this.proteinGoal,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    
   // Makro besin yüzdelerini hesapla
final totalGrams = totalCarbs + totalFat + totalProtein;
final carbsPercentOfTotal = totalGrams > 0 ? (totalCarbs / totalGrams * 100) : 0.0;
final fatPercentOfTotal = totalGrams > 0 ? (totalFat / totalGrams * 100) : 0.0;
final proteinPercentOfTotal = totalGrams > 0 ? (totalProtein / totalGrams * 100) : 0.0;

// Kalori dağılımını hesapla
final carbsCalories = totalCarbs * 4;
final fatCalories = totalFat * 9;
final proteinCalories = totalProtein * 4;

// Hedef yüzdelerini hesapla
final caloriePercent = calorieGoal > 0 ? (totalCalories / calorieGoal * 100) : 0.0;
final carbPercent = carbGoal > 0 ? (totalCarbs / carbGoal * 100) : 0.0;
final fatPercent = fatGoal > 0 ? (totalFat / fatGoal * 100) : 0.0;
final proteinPercent = proteinGoal > 0 ? (totalProtein / proteinGoal * 100) : 0.0;
    
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$dateStr Besin Değerleri',
              style: const TextStyle(
                fontSize: 18, 
                fontWeight: FontWeight.bold
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Toplam Kalori'),
                Row(
                  children: [
                    Text(
                      '$totalCalories kcal',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 16),
                    // Small circular chart placeholder
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildNutrientRow(
              'Karbonhidrat', 
  totalCarbs, 
  carbsPercentOfTotal, // Güncellenen değişken adı
  Colors.blue, 
  carbPercent
            ),
            const SizedBox(height: 8),
            _buildNutrientRow(
              'Yağ', 
              totalFat, 
              fatPercentOfTotal, 
              Colors.orange, 
              fatPercent
            ),
            const SizedBox(height: 8),
            _buildNutrientRow(
              'Protein', 
              totalProtein, 
              proteinPercentOfTotal, 
              Colors.purple, 
              proteinPercent
            ),
            const SizedBox(height: 16),
            const Text(
              'Kalori Dağılımı:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildCalorieDistributionRow(
              'Karbonhidrat', 
              carbsCalories, 
              carbsPercentOfTotal, 
              Colors.blue
            ),
            _buildCalorieDistributionRow(
              'Yağ', 
              fatCalories, 
              fatPercentOfTotal, 
              Colors.orange
            ),
            _buildCalorieDistributionRow(
              'Protein', 
              proteinCalories, 
              proteinPercentOfTotal, 
              Colors.purple
            ),
            const SizedBox(height: 16),
            const Text(
              'Hedef Karşılaştırması:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildGoalComparisonRow(
              'Kalori', 
              totalCalories.toDouble(), 
              calorieGoal.toDouble(), 
              'kcal', 
              Colors.green,
              caloriePercent
            ),
            const SizedBox(height: 4),
            _buildGoalComparisonRow(
              'Karbonhidrat', 
              totalCarbs, 
              carbGoal, 
              'g', 
              Colors.blue,
              carbPercent
            ),
            const SizedBox(height: 4),
            _buildGoalComparisonRow(
              'Yağ', 
              totalFat, 
              fatGoal, 
              'g', 
              Colors.orange,
              fatPercent
            ),
            const SizedBox(height: 4),
            _buildGoalComparisonRow(
              'Protein', 
              totalProtein, 
              proteinGoal, 
              'g', 
              Colors.purple,
              proteinPercent
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNutrientRow(String name, double value, double percentage, Color color, double goalPercentage) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(name),
        Row(
          children: [
            Text(
              '${value.toStringAsFixed(1)} g (${percentage.toStringAsFixed(1)}%)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCalorieDistributionRow(String name, double calories, double percentage, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '$name: ${calories.toStringAsFixed(1)} kcal',
            style: const TextStyle(fontSize: 14),
          ),
        ),
        Text(
          '${percentage.toStringAsFixed(1)}%',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildGoalComparisonRow(String name, double value, double goal, String unit, Color color, double percentage) {
    final isOverGoal = value > goal;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '$name: ${value.toStringAsFixed(1)} / ${goal.toStringAsFixed(1)} $unit',
                style: const TextStyle(fontSize: 14),
              ),
            ),
            Text(
              '${percentage.toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isOverGoal ? Colors.red : color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (percentage / 100).clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(
              isOverGoal ? Colors.red : color,
            ),
          ),
        ),
      ],
    );
  }
}