import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/transaction_model.dart';
import '../models/obligation_model.dart';
import '../services/api_service.dart';
import 'login_screen.dart';
import 'add_transaction_screen.dart';
import 'chatbot_screen.dart';
import 'calendar_screen.dart';
import 'payment_methods_screen.dart';
import 'financial_history_screen.dart';
import 'notifications_screen.dart';
import 'financial_profile_screen.dart';
import 'statistics_screen.dart';

class HomeScreen extends StatefulWidget {
  final String token;
  final Map<String, dynamic> user;

  const HomeScreen({super.key, required this.token, required this.user});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<TransactionModel>> _transactionsFuture;
  late Future<List<ObligationModel>> _obligationsFuture;
  late Future<Map<String, dynamic>> _profileFuture;

  Map<String, dynamic>? _assistantSuggestion;

  final NumberFormat _moneyFormat = NumberFormat('#,##0', 'es_CO');

  static const Color primaryColor = Color(0xFF7569B5);
  static const Color darkColor = Color(0xFF292638);
  static const Color backgroundColor = Color(0xFFF7F6FC);

  @override
  void initState() {
    super.initState();
    _loadTransactions();
    _loadObligations();
    _loadProfile();
  }

  void _loadTransactions() {
    _transactionsFuture = ApiService.getTransactionsList(token: widget.token);
  }

  void _loadObligations() {
    _obligationsFuture = ApiService.getObligations(token: widget.token)
        .then((data) {
          final List obligations = data['obligations'] ?? [];

          return obligations.map((item) {
            return ObligationModel.fromJson(Map<String, dynamic>.from(item));
          }).toList();
        });
  }

  void _loadProfile() {
    _profileFuture = ApiService.getProfile(token: widget.token);
  }

  void _refreshTransactions() {
    setState(() {
      _loadTransactions();
    });
  }

  void _refreshObligations() {
    if (!mounted) return;

    setState(() {
      _loadObligations();
    });
  }

  String _formatMoney(double amount) {
    return '\$${_moneyFormat.format(amount)}';
  }

  // ==========================================
  // SUGERENCIA PROACTIVA DE WISE ASSISTANT
  // ==========================================

  Future<void> _showAssistantSuggestion(Map<String, dynamic> movement) async {
    final type = (movement['type'] ?? '').toString().toLowerCase();
    final description = (movement['description'] ?? '').toString().trim();
    final category = (movement['category'] ?? '').toString().trim();
    final amountValue = movement['amount'];

    final amount = amountValue is num
        ? amountValue.toDouble()
        : double.tryParse(amountValue?.toString() ?? '') ?? 0;

    // Consultar el perfil financiero.
    Map<String, dynamic>? profile;

    try {
      final profileData = await _profileFuture;
      final profileValue = profileData['profile'];

      if (profileValue is Map) {
        profile = Map<String, dynamic>.from(profileValue);
      }
    } catch (_) {
      profile = null;
    }

    // Consultar las obligaciones registradas.
    List<ObligationModel> obligations = [];

    try {
      obligations = await _obligationsFuture;
    } catch (_) {
      obligations = [];
    }

    final pendingObligations = obligations
        .where((obligation) => obligation.isPending)
        .toList();

    final overdueObligations = pendingObligations
        .where((obligation) => obligation.isOverdue)
        .toList();

    final pendingTotal = pendingObligations.fold<double>(
      0,
      (total, obligation) => total + obligation.amount,
    );

    final overdueTotal = overdueObligations.fold<double>(
      0,
      (total, obligation) => total + obligation.amount,
    );

    // Obtener la meta de ahorro.
    final savingsGoalText = (profile?['savings_goal'] ?? '').toString();
    final goalMatch = RegExp(r'\d[\d.,]*').firstMatch(savingsGoalText);

    double? savingsGoal;

    if (goalMatch != null) {
      final digits = goalMatch.group(0)!.replaceAll(RegExp(r'[^0-9]'), '');
      final parsedGoal = double.tryParse(digits);

      if (parsedGoal != null && parsedGoal > 0) {
        savingsGoal = parsedGoal;
      }
    }

    // Obtener el ahorro acumulado declarado por el usuario.
    final accumulatedValue = profile?['savings_accumulated'];

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

    // Calcular el progreso de ahorro.
    String? savingsProgressMessage;

    if (savingsGoal != null && savingsAccumulated != null) {
      final remaining = savingsGoal - savingsAccumulated;
      final percentage = (savingsAccumulated / savingsGoal) * 100;

      if (remaining > 0) {
        savingsProgressMessage =
            'Tu ahorro acumulado es de ${_formatMoney(savingsAccumulated)} '
            'y llevas un avance del ${percentage.toStringAsFixed(1)}% '
            'de tu meta. Te faltan ${_formatMoney(remaining)} para alcanzarla.';
      } else if (remaining == 0) {
        savingsProgressMessage =
            '¡Ya alcanzaste tu meta de ahorro de ${_formatMoney(savingsGoal)}! '
            'Tu ahorro acumulado es de ${_formatMoney(savingsAccumulated)}.';
      } else {
        savingsProgressMessage =
            '¡Has superado tu meta de ahorro! '
            'Tu ahorro acumulado es de ${_formatMoney(savingsAccumulated)}, '
            'superando la meta de ${_formatMoney(savingsGoal)} '
            'por ${_formatMoney(remaining.abs())}.';
      }
    }

    final movementText = '$description $category'.toLowerCase();

    final isLoan = RegExp(r'\b(prestamo|pr[eé]stamo|credito|cr[eé]dito)\b')
        .hasMatch(movementText);

    final hasPending = pendingObligations.isNotEmpty;
    final hasOverdue = overdueObligations.isNotEmpty;

    String title;
    String message;
    IconData icon;

    // INGRESO IDENTIFICADO COMO PRÉSTAMO.
    if (type == 'ingreso' && isLoan) {
      title = 'Ten presente este préstamo';

      message =
          'Registraste ${_formatMoney(amount)} como ingreso, '
          'pero si corresponde a un préstamo, recuerda que es dinero '
          'que tendrás que devolver y no un ingreso propio.';

      if (hasOverdue) {
        message +=
            ' Además, tienes ${overdueObligations.length} obligaciones '
            'vencidas por ${_formatMoney(overdueTotal)}. '
            'Conviene priorizar esos compromisos.';
      } else if (hasPending) {
        message +=
            ' También tienes ${pendingObligations.length} obligaciones '
            'pendientes por ${_formatMoney(pendingTotal)}.';
      }

      if (savingsProgressMessage != null) {
        message += ' $savingsProgressMessage';
      }

      icon = Icons.info_outline_rounded;
    }
    // INGRESO NORMAL.
    else if (type == 'ingreso') {
      title = 'Un ingreso registrado';

      if (hasOverdue) {
        message =
            'Registraste ${_formatMoney(amount)}. Tienes '
            '${overdueObligations.length} obligaciones vencidas '
            'por ${_formatMoney(overdueTotal)}. '
            'Te recomendamos priorizar esos pagos antes de destinar '
            'dinero adicional al ahorro.';
      } else if (hasPending) {
        message =
            'Registraste ${_formatMoney(amount)}. Tienes '
            '${pendingObligations.length} obligaciones pendientes '
            'por ${_formatMoney(pendingTotal)}. '
            'Considera tus próximos pagos antes de distribuir este dinero.';
      } else {
        message =
            'Registraste ${_formatMoney(amount)}. '
            'Recuerda organizar este ingreso teniendo en cuenta '
            'tus compromisos y tus objetivos financieros.';
      }

      if (savingsProgressMessage != null) {
        message += ' $savingsProgressMessage';
      } else if (savingsGoal != null) {
        message += ' Tu meta de ahorro es de ${_formatMoney(savingsGoal)}.';
      }

      if (hasOverdue || hasPending) {
        message +=
            ' Procura mantener tus obligaciones al día '
            'antes de aumentar tus aportes de ahorro.';
      } else if (savingsGoal != null &&
          savingsAccumulated != null &&
          savingsAccumulated >= savingsGoal) {
        message +=
            ' Puedes establecer una nueva meta o mantener '
            'el hábito de ahorro que has construido.';
      } else {
        message +=
            ' Mantén aportes graduales y constantes '
            'según tus posibilidades.';
      }

      icon = Icons.trending_up_rounded;
    }
    // GASTO.
    else {
      title = 'Un gasto registrado';

      final categoryText = category.isEmpty ? 'esta categoría' : category;

      message =
          'Registraste ${_formatMoney(amount)} en $categoryText. '
          'Ten presente este valor al revisar tu balance '
          'y planear tus próximos pagos.';

      if (hasOverdue) {
        message +=
            ' Tienes ${overdueObligations.length} obligaciones vencidas '
            'por ${_formatMoney(overdueTotal)}. '
            'Conviene priorizar esos pagos.';
      } else if (hasPending) {
        message +=
            ' También tienes ${pendingObligations.length} obligaciones '
            'pendientes por ${_formatMoney(pendingTotal)}.';
      }

      if (savingsProgressMessage != null) {
        message += ' $savingsProgressMessage';
      } else if (savingsGoal != null) {
        message +=
            ' Recuerda tu meta de ahorro de ${_formatMoney(savingsGoal)} '
            'al organizar tus próximos gastos.';
      }

      if (hasOverdue || hasPending) {
        message +=
            ' Procura mantener tus obligaciones al día '
            'antes de aumentar tus aportes de ahorro.';
      }

      icon = Icons.trending_down_rounded;
    }

    if (!mounted) return;

    setState(() {
      _assistantSuggestion = {'title': title, 'message': message, 'icon': icon};
    });
  }

  void _dismissAssistantSuggestion() {
    setState(() {
      _assistantSuggestion = null;
    });
  }

  Widget _buildAssistantSuggestionCard() {
    final suggestion = _assistantSuggestion!;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 300),
      child: Material(
        color: Colors.white,
        elevation: 8,
        borderRadius: BorderRadius.circular(17),
        child: Container(
          padding: const EdgeInsets.fromLTRB(13, 11, 5, 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: primaryColor.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Icon(
                suggestion['icon'] as IconData,
                color: primaryColor,
                size: 25,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: _openChatbot,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          suggestion['title'] as String,
                          style: const TextStyle(
                            color: darkColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          suggestion['message'] as String,
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 11,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 5),
                        const Text(
                          'Toca para conversar con Wise Assistant',
                          style: TextStyle(
                            color: primaryColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Cerrar sugerencia',
                visualDensity: VisualDensity.compact,
                onPressed: _dismissAssistantSuggestion,
                icon: const Icon(Icons.close, size: 18, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // CONTAR NOTIFICACIONES
  // ==========================================

  int _getNotificationCount(List<ObligationModel> obligations) {
    final today = DateUtils.dateOnly(DateTime.now());
    final lastNotificationDate = today.add(const Duration(days: 3));

    return obligations.where((obligation) {
      if (!obligation.isPending) return false;

      final dueDate = DateUtils.dateOnly(obligation.dueDate);

      return !dueDate.isAfter(lastNotificationDate);
    }).length;
  }

  // ==========================================
  // ABRIR CENTRO DE NOTIFICACIONES
  // ==========================================

  Future<void> _openNotifications() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NotificationsScreen(token: widget.token),
      ),
    );

    if (mounted) {
      _refreshObligations();
    }
  }

  // ==========================================
  // SELECCIONAR TIPO DE MOVIMIENTO
  // ==========================================

  Future<void> _showAddMovementOptions() async {
    final selectedType = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return Container(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                '¿Qué movimiento deseas registrar?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: darkColor,
                ),
              ),
              const SizedBox(height: 7),
              const Text(
                'Selecciona el tipo de transacción.',
                style: TextStyle(color: Colors.black54, fontSize: 13),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(bottomSheetContext, 'ingreso');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade50,
                    foregroundColor: Colors.green.shade800,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      vertical: 18,
                      horizontal: 18,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.green.shade200),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.trending_up, size: 27),
                      SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Registrar ingreso',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Dinero que recibes.',
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios, size: 17),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 13),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(bottomSheetContext, 'gasto');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade50,
                    foregroundColor: Colors.red.shade700,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      vertical: 18,
                      horizontal: 18,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.red.shade200),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.trending_down, size: 27),
                      SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Registrar gasto',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Dinero que utilizas o pagas.',
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios, size: 17),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (selectedType == null || !mounted) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddTransactionScreen(
          token: widget.token,
          initialTransactionType: selectedType,
        ),
      ),
    );

    if (!mounted) return;

    if (result is Map) {
      _refreshTransactions();
      _showAssistantSuggestion(Map<String, dynamic>.from(result));
    } else if (result == true) {
      _refreshTransactions();
    }
  }

  // ==========================================
  // ABRIR CHATBOT
  // ==========================================

  void _openChatbot() {
    if (_assistantSuggestion != null) {
      _dismissAssistantSuggestion();
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ChatbotScreen(token: widget.token)),
    );
  }

  // ==========================================
  // ABRIR CALENDARIO
  // ==========================================

  Future<void> _openCalendar() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CalendarScreen(token: widget.token)),
    );

    if (!mounted) return;

    setState(() {
      _loadObligations();
      _assistantSuggestion = null;
    });
  }

  Future<void> _openFinancialProfile() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FinancialProfileScreen(
          token: widget.token,
          user: widget.user,
          isEditing: true,
        ),
      ),
    );

    if (!mounted) return;

    if (result == true) {
      setState(() {
        _loadProfile();
        _assistantSuggestion = null;
      });
    }
  }

  // ==========================================
  // ABRIR ESTADÍSTICAS FINANCIERAS
  // ==========================================

  void _openStatistics() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => StatisticsScreen(token: widget.token)),
    );
  }

  // ==========================================
  // ABRIR MEDIOS DE PAGO
  // ==========================================

  void _openPaymentMethods() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PaymentMethodsScreen()),
    );
  }

  // ==========================================
  // ABRIR HISTORIAL FINANCIERO
  // ==========================================

  void _openFinancialHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FinancialHistoryScreen(token: widget.token),
      ),
    );
  }

  // ==========================================
  // EDITAR TRANSACCION
  // ==========================================

  Future<void> _editTransaction(TransactionModel transaction) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            AddTransactionScreen(token: widget.token, transaction: transaction),
      ),
    );

    if (result == true && mounted) {
      _refreshTransactions();
    }
  }

  // ==========================================
  // ELIMINAR TRANSACCION
  // ==========================================

  Future<void> _deleteTransaction(TransactionModel transaction) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Eliminar transacción'),
          content: Text(
            '¿Estás seguro de que deseas eliminar '
            '"${transaction.description}"?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    try {
      await ApiService.deleteTransaction(
        token: widget.token,
        transactionId: transaction.id,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transacción eliminada correctamente.'),
          backgroundColor: Colors.green,
        ),
      );

      _refreshTransactions();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo eliminar: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ==========================================
  // CERRAR SESION
  // ==========================================

  void _logout() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  // ==========================================
  // TARJETA DE MODULO
  // ==========================================

  Widget _buildModuleCard({
    required String title,
    required String description,
    required IconData icon,
    required VoidCallback onTap,
    required Color color,
  }) {
    return Card(
      elevation: 0,
      color: Colors.white,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 25),
              ),
              const SizedBox(height: 13),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: darkColor,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black54,
                  height: 1.4,
                ),
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(Icons.arrow_forward_rounded, color: color, size: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // TARJETA DE INGRESOS Y GASTOS
  // ==========================================

  Widget _buildSummaryCard({
    required String title,
    required double amount,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              _formatMoney(amount),
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // INTERFAZ PRINCIPAL
  // ==========================================

  @override
  Widget build(BuildContext context) {
    final name = widget.user['name'] ?? 'Usuario';

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        backgroundColor: backgroundColor,
        foregroundColor: darkColor,
        title: const Text(
          'Wise Wallet',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 21,
            color: darkColor,
          ),
        ),
        actions: [
          // PERFIL FINANCIERO
          IconButton(
            tooltip: 'Mi perfil financiero',
            onPressed: _openFinancialProfile,
            icon: const Icon(Icons.account_circle_outlined),
          ),
          // CAMPANA DE NOTIFICACIONES
          FutureBuilder<List<ObligationModel>>(
            future: _obligationsFuture,
            builder: (context, snapshot) {
              final count = snapshot.hasData
                  ? _getNotificationCount(snapshot.data!)
                  : 0;

              return IconButton(
                tooltip: 'Notificaciones',
                onPressed: _openNotifications,
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.notifications_none_rounded),
                    if (count > 0)
                      Positioned(
                        right: -7,
                        top: -5,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          constraints: const BoxConstraints(
                            minWidth: 17,
                            minHeight: 17,
                          ),
                          decoration: const BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            count > 99 ? '99+' : '$count',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Actualizar información',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _refreshTransactions();
              _refreshObligations();
            },
          ),
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
          const SizedBox(width: 8),
        ],
      ),

      // CHATBOT FLOTANTE Y SUGERENCIA PROACTIVA
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_assistantSuggestion != null) ...[
            _buildAssistantSuggestionCard(),
            const SizedBox(height: 12),
          ],
          FloatingActionButton(
            onPressed: _openChatbot,
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            elevation: 5,
            tooltip: 'Abrir Wise Assistant',
            child: const Icon(Icons.smart_toy_outlined, size: 29),
          ),
        ],
      ),

      body: FutureBuilder<List<TransactionModel>>(
        future: _transactionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: primaryColor),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 60,
                      color: Colors.redAccent,
                    ),
                    const SizedBox(height: 15),
                    const Text(
                      'No fue posible cargar tus transacciones.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 17),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _refreshTransactions,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Intentar nuevamente'),
                    ),
                  ],
                ),
              ),
            );
          }

          final transactions = snapshot.data ?? [];

          double totalIncome = 0;
          double totalExpenses = 0;

          for (final transaction in transactions) {
            if (transaction.transactionType == 'ingreso') {
              totalIncome += transaction.amount;
            } else if (transaction.transactionType == 'gasto') {
              totalExpenses += transaction.amount;
            }
          }

          final balance = totalIncome - totalExpenses;

          return LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 750;

              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(22, 18, 22, 90),
                    children: [
                      Text(
                        '¡Hola, $name!',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: darkColor,
                        ),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'Este es el resumen de tus finanzas.',
                        style: TextStyle(fontSize: 14, color: Colors.black54),
                      ),
                      const SizedBox(height: 23),

                      // BALANCE PRINCIPAL
                      Container(
                        padding: const EdgeInsets.all(25),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF8175C4), Color(0xFF62569F)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withValues(alpha: 0.20),
                              blurRadius: 15,
                              offset: const Offset(0, 7),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.account_balance_wallet_outlined,
                                  color: Colors.white70,
                                  size: 22,
                                ),
                                SizedBox(width: 9),
                                Text(
                                  'BALANCE DISPONIBLE',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 17),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                _formatMoney(balance),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 34,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            const Divider(color: Colors.white30, height: 1),
                            const SizedBox(height: 13),
                            const Row(
                              children: [
                                Icon(
                                  Icons.insights_outlined,
                                  color: Colors.white70,
                                  size: 17,
                                ),
                                SizedBox(width: 7),
                                Text(
                                  'Resumen de tus movimientos registrados',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),

                      // AGREGAR MOVIMIENTO
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _showAddMovementOptions,
                          icon: const Icon(Icons.add_circle_outline, size: 25),
                          label: const Text('Agregar movimiento'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            elevation: 3,
                            padding: const EdgeInsets.symmetric(vertical: 19),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 17),

                      // INGRESOS Y GASTOS
                      Row(
                        children: [
                          Expanded(
                            child: _buildSummaryCard(
                              title: 'Ingresos',
                              amount: totalIncome,
                              icon: Icons.trending_up,
                              color: Colors.green.shade700,
                            ),
                          ),
                          const SizedBox(width: 13),
                          Expanded(
                            child: _buildSummaryCard(
                              title: 'Gastos',
                              amount: totalExpenses,
                              icon: Icons.trending_down,
                              color: Colors.redAccent,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 30),

                      // MODULOS
                      const Text(
                        'Explora tus herramientas',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: darkColor,
                        ),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'Organiza y administra tus finanzas.',
                        style: TextStyle(fontSize: 13, color: Colors.black54),
                      ),
                      const SizedBox(height: 15),

                      GridView.count(
                        crossAxisCount: isWide ? 3 : 2,
                        crossAxisSpacing: 13,
                        mainAxisSpacing: 13,
                        childAspectRatio: isWide ? 1.45 : 1.05,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          _buildModuleCard(
                            title: 'Calendario de pagos',
                            description:
                                'Controla tus obligaciones y vencimientos.',
                            icon: Icons.calendar_month_outlined,
                            color: const Color(0xFF7569B5),
                            onTap: _openCalendar,
                          ),
                          _buildModuleCard(
                            title: 'Medios de pago',
                            description:
                                'Conoce las opciones para realizar tus pagos.',
                            icon: Icons.account_balance_wallet_outlined,
                            color: const Color(0xFF388E8E),
                            onTap: _openPaymentMethods,
                          ),
                          _buildModuleCard(
                            title: 'Historial financiero',
                            description:
                                'Consulta tus ingresos y gastos registrados.',
                            icon: Icons.history,
                            color: const Color(0xFFDB9140),
                            onTap: _openFinancialHistory,
                          ),
                          _buildModuleCard(
                            title: 'Estadísticas financieras',
                            description:
                                'Visualiza tu ahorro, ingresos y gastos.',
                            icon: Icons.bar_chart_rounded,
                            color: const Color(0xFF8B78B8),
                            onTap: _openStatistics,
                          ),
                        ],
                      ),

                      const SizedBox(height: 30),

                      // TRANSACCIONES RECIENTES
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Text(
                              'Transacciones recientes',
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                                color: darkColor,
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _openFinancialHistory,
                            icon: const Icon(Icons.arrow_forward, size: 16),
                            label: const Text('Ver historial'),
                            style: TextButton.styleFrom(
                              foregroundColor: primaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      if (transactions.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: const Column(
                            children: [
                              Icon(
                                Icons.receipt_long_outlined,
                                size: 45,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 12),
                              Text(
                                'Todavía no tienes transacciones.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.black54,
                                  fontSize: 14,
                                ),
                              ),
                              SizedBox(height: 5),
                              Text(
                                'Agrega tu primer movimiento para comenzar.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        ...transactions.map((transaction) {
                          final isIncome =
                              transaction.transactionType == 'ingreso';

                          return Card(
                            elevation: 0,
                            color: Colors.white,
                            margin: const EdgeInsets.only(bottom: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(color: Colors.grey.shade200),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 15,
                                vertical: 5,
                              ),
                              leading: CircleAvatar(
                                radius: 22,
                                backgroundColor: isIncome
                                    ? Colors.green.shade50
                                    : Colors.red.shade50,
                                child: Icon(
                                  isIncome
                                      ? Icons.arrow_downward
                                      : Icons.arrow_upward,
                                  color: isIncome
                                      ? Colors.green.shade700
                                      : Colors.redAccent,
                                  size: 21,
                                ),
                              ),
                              title: Text(
                                transaction.description,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: Text(
                                transaction.category,
                                style: const TextStyle(fontSize: 12),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${isIncome ? '+' : '-'}'
                                    '${_formatMoney(transaction.amount)}',
                                    textAlign: TextAlign.end,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: isIncome
                                          ? Colors.green.shade700
                                          : Colors.redAccent,
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    tooltip: 'Opciones',
                                    onSelected: (value) {
                                      if (value == 'editar') {
                                        _editTransaction(transaction);
                                      } else if (value == 'eliminar') {
                                        _deleteTransaction(transaction);
                                      }
                                    },
                                    itemBuilder: (context) => const [
                                      PopupMenuItem(
                                        value: 'editar',
                                        child: Row(
                                          children: [
                                            Icon(Icons.edit, size: 20),
                                            SizedBox(width: 10),
                                            Text('Editar'),
                                          ],
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: 'eliminar',
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.delete_outline,
                                              size: 20,
                                              color: Colors.red,
                                            ),
                                            SizedBox(width: 10),
                                            Text('Eliminar'),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
