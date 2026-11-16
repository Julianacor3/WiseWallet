import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/transaction_model.dart';
import '../services/api_service.dart';

class StatisticsScreen extends StatefulWidget {
  final String token;

  const StatisticsScreen({super.key, required this.token});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  late Future<_StatisticsData> _statisticsFuture;

  final NumberFormat _moneyFormat = NumberFormat('#,##0', 'es_CO');

  static const Color primaryColor = Color(0xFF7569B5);
  static const Color darkColor = Color(0xFF292638);
  static const Color backgroundColor = Color(0xFFF7F6FC);

  static const List<Color> chartColors = [
    Color(0xFF7569B5),
    Color(0xFF388E8E),
    Color(0xFFDB9140),
    Color(0xFFE57373),
    Color(0xFF6488C5),
    Color(0xFF9B75A8),
    Color(0xFF80A66A),
    Color(0xFFB88C62),
  ];

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  void _loadStatistics() {
    _statisticsFuture = _fetchStatistics();
  }

  Future<_StatisticsData> _fetchStatistics() async {
    final results = await Future.wait([
      ApiService.getTransactionsList(token: widget.token),
      ApiService.getProfile(token: widget.token),
    ]);

    final transactions = results[0] as List<TransactionModel>;
    final profileData = results[1] as Map<String, dynamic>;

    final profileValue = profileData['profile'];

    final profile = profileValue is Map
        ? Map<String, dynamic>.from(profileValue)
        : <String, dynamic>{};

    double totalIncome = 0;
    double totalExpenses = 0;

    final Map<String, double> expensesByCategory = {};

    for (final transaction in transactions) {
      if (transaction.transactionType == 'ingreso') {
        totalIncome += transaction.amount;
      } else if (transaction.transactionType == 'gasto') {
        totalExpenses += transaction.amount;

        final category = transaction.category.trim().isEmpty
            ? 'Sin categoría'
            : transaction.category.trim();

        expensesByCategory[category] =
            (expensesByCategory[category] ?? 0) + transaction.amount;
      }
    }

    final savingsGoalText = (profile['savings_goal'] ?? '').toString();

    final goalMatch = RegExp(r'\d[\d.,]*').firstMatch(savingsGoalText);

    double? savingsGoal;

    if (goalMatch != null) {
      final digits = goalMatch.group(0)!.replaceAll(RegExp(r'[^0-9]'), '');
      final parsed = double.tryParse(digits);

      if (parsed != null && parsed > 0) {
        savingsGoal = parsed;
      }
    }

    final accumulatedValue = profile['savings_accumulated'];

    double? savingsAccumulated;

    if (accumulatedValue is num) {
      savingsAccumulated = accumulatedValue.toDouble();
    } else if (accumulatedValue != null) {
      savingsAccumulated = double.tryParse(accumulatedValue.toString());
    }

    if (savingsAccumulated != null &&
        (!savingsAccumulated.isFinite || savingsAccumulated < 0)) {
      savingsAccumulated = null;
    }

    final sortedCategories = expensesByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return _StatisticsData(
      totalIncome: totalIncome,
      totalExpenses: totalExpenses,
      balance: totalIncome - totalExpenses,
      savingsGoal: savingsGoal,
      savingsAccumulated: savingsAccumulated,
      expensesByCategory: sortedCategories,
    );
  }

  String _formatMoney(double amount) {
    return '\$${_moneyFormat.format(amount)}';
  }

  Widget _buildSectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: darkColor,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ],
    );
  }

  Widget _buildSavingsCard(_StatisticsData data) {
    final goal = data.savingsGoal;
    final accumulated = data.savingsAccumulated;

    final hasSavingsData = goal != null && accumulated != null;

    final percentage = hasSavingsData ? (accumulated / goal) * 100 : 0.0;

    final progress = (percentage / 100).clamp(0.0, 1.0);

    final remaining = hasSavingsData ? goal - accumulated : 0.0;

    String statusMessage;

    if (!hasSavingsData) {
      statusMessage = 'Completa tu perfil para consultar tu progreso.';
    } else if (remaining > 0) {
      statusMessage =
          'Te faltan ${_formatMoney(remaining)} para alcanzar tu meta.';
    } else if (remaining == 0) {
      statusMessage = '¡Has alcanzado tu meta de ahorro!';
    } else {
      statusMessage =
          '¡Has superado tu meta por ${_formatMoney(remaining.abs())}!';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF8175C4), Color(0xFF62569F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.savings_outlined, color: Colors.white, size: 23),
              SizedBox(width: 9),
              Text(
                'PROGRESO DE AHORRO',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            hasSavingsData ? _formatMoney(accumulated) : 'Sin información',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Ahorro acumulado actual',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Meta de ahorro',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              Text(
                goal != null ? _formatMoney(goal) : 'No definida',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: hasSavingsData ? progress : 0,
              minHeight: 11,
              backgroundColor: Colors.white30,
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFFBCE7D3),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                hasSavingsData
                    ? '${percentage.toStringAsFixed(1)}% completado'
                    : 'Sin porcentaje disponible',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (hasSavingsData && percentage > 100)
                const Text(
                  'Meta superada',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 15),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              statusMessage,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonCard(_StatisticsData data) {
    final maxAmount = math.max(data.totalIncome, data.totalExpenses);

    final incomeProgress = maxAmount > 0 ? data.totalIncome / maxAmount : 0.0;

    final expensesProgress = maxAmount > 0
        ? data.totalExpenses / maxAmount
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildComparisonBar(
            title: 'Ingresos registrados',
            amount: data.totalIncome,
            progress: incomeProgress,
            color: Colors.green.shade600,
            icon: Icons.trending_up_rounded,
          ),
          const SizedBox(height: 23),
          _buildComparisonBar(
            title: 'Gastos registrados',
            amount: data.totalExpenses,
            progress: expensesProgress,
            color: Colors.redAccent,
            icon: Icons.trending_down_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonBar({
    required String title,
    required double amount,
    required double progress,
    required Color color,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: darkColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              _formatMoney(amount),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 12,
            backgroundColor: Colors.grey.shade100,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildBalanceCard(_StatisticsData data) {
    final isPositive = data.balance >= 0;
    final color = isPositive ? Colors.green.shade700 : Colors.redAccent;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.account_balance_wallet_outlined,
              color: color,
              size: 25,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Balance de movimientos',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 5),
                Text(
                  _formatMoney(data.balance),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            isPositive
                ? Icons.arrow_upward_rounded
                : Icons.arrow_downward_rounded,
            color: color,
            size: 24,
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(_StatisticsData data) {
    final categories = data.expensesByCategory;
    final total = data.totalExpenses;

    if (categories.isEmpty || total <= 0) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(25),
        decoration: _cardDecoration(),
        child: const Column(
          children: [
            Icon(Icons.pie_chart_outline_rounded, color: Colors.grey, size: 42),
            SizedBox(height: 12),
            Text(
              'Todavía no tienes gastos registrados.',
              style: TextStyle(color: Colors.black54, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          SizedBox(
            height: 190,
            child: Row(
              children: [
                Expanded(
                  child: CustomPaint(
                    size: const Size(180, 180),
                    painter: _DonutChartPainter(
                      categories: categories,
                      total: total,
                      colors: chartColors,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total de gastos',
                        style: TextStyle(color: Colors.black54, fontSize: 11),
                      ),
                      const SizedBox(height: 5),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _formatMoney(total),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: darkColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${categories.length} categorías',
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 25),
          ...categories.asMap().entries.map((entry) {
            final index = entry.key;
            final category = entry.value;
            final percentage = (category.value / total) * 100;
            final color = chartColors[index % chartColors.length];

            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                children: [
                  Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      category.key,
                      style: const TextStyle(fontSize: 12, color: darkColor),
                    ),
                  ),
                  Text(
                    '${percentage.toStringAsFixed(1)}%',
                    style: const TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _formatMoney(category.value),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: darkColor,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.grey.shade200),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        foregroundColor: darkColor,
        elevation: 0,
        title: const Text(
          'Estadísticas financieras',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 19,
            color: darkColor,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Actualizar estadísticas',
            onPressed: () {
              setState(_loadStatistics);
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 5),
        ],
      ),
      body: FutureBuilder<_StatisticsData>(
        future: _statisticsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: primaryColor),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(25),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 55,
                      color: Colors.redAccent,
                    ),
                    const SizedBox(height: 15),
                    const Text(
                      'No fue posible cargar tus estadísticas.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 15),
                    ),
                    const SizedBox(height: 15),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(_loadStatistics);
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Intentar nuevamente'),
                    ),
                  ],
                ),
              ),
            );
          }

          final data = snapshot.data!;

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 850),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 15, 20, 35),
                children: [
                  const Text(
                    'Conoce el estado de tus finanzas',
                    style: TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                  const SizedBox(height: 20),

                  _buildSavingsCard(data),

                  const SizedBox(height: 27),

                  _buildSectionTitle(
                    'Ingresos y gastos',
                    'Comparación de todos tus movimientos registrados.',
                  ),
                  const SizedBox(height: 13),
                  _buildComparisonCard(data),

                  const SizedBox(height: 25),

                  _buildSectionTitle(
                    'Distribución de gastos',
                    'Conoce en qué categorías has utilizado tu dinero.',
                  ),
                  const SizedBox(height: 13),
                  _buildCategoryCard(data),

                  const SizedBox(height: 25),

                  _buildSectionTitle(
                    'Balance financiero',
                    'Resultado de tus ingresos menos tus gastos registrados.',
                  ),
                  const SizedBox(height: 13),
                  _buildBalanceCard(data),

                  const SizedBox(height: 20),

                  const Text(
                    'Los valores corresponden a los movimientos registrados '
                    'en Wise Wallet. El ahorro acumulado es el valor declarado '
                    'en tu perfil financiero.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.black45,
                      fontSize: 11,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StatisticsData {
  final double totalIncome;
  final double totalExpenses;
  final double balance;
  final double? savingsGoal;
  final double? savingsAccumulated;
  final List<MapEntry<String, double>> expensesByCategory;

  const _StatisticsData({
    required this.totalIncome,
    required this.totalExpenses,
    required this.balance,
    required this.savingsGoal,
    required this.savingsAccumulated,
    required this.expensesByCategory,
  });
}

class _DonutChartPainter extends CustomPainter {
  final List<MapEntry<String, double>> categories;
  final double total;
  final List<Color> colors;

  _DonutChartPainter({
    required this.categories,
    required this.total,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 5;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 25
      ..strokeCap = StrokeCap.butt;

    double startAngle = -math.pi / 2;

    for (int i = 0; i < categories.length; i++) {
      final sweepAngle = (categories[i].value / total) * 2 * math.pi;

      paint.color = colors[i % colors.length];

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );

      startAngle += sweepAngle;
    }

    final centerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius - 14, centerPaint);
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return oldDelegate.categories != categories || oldDelegate.total != total;
  }
}
