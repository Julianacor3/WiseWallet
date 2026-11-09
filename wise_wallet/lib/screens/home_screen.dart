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

  final NumberFormat _moneyFormat = NumberFormat.currency(
    locale: 'es_CO',
    symbol: '\$ ',
    decimalDigits: 2,
  );

  static const Color primaryColor = Color(0xFF7569B5);
  static const Color darkColor = Color(0xFF292638);
  static const Color backgroundColor = Color(0xFFF7F6FC);

  @override
  void initState() {
    super.initState();
    _loadTransactions();
    _loadObligations();
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
    return _moneyFormat.format(amount);
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

    if (result == true && mounted) {
      _refreshTransactions();
    }
  }

  // ==========================================
  // ABRIR CHATBOT
  // ==========================================

  void _openChatbot() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ChatbotScreen(token: widget.token)),
    );
  }

  // ==========================================
  // ABRIR CALENDARIO
  // ==========================================

  void _openCalendar() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CalendarScreen(token: widget.token)),
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

      // CHATBOT FLOTANTE
      floatingActionButton: FloatingActionButton(
        onPressed: _openChatbot,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 5,
        tooltip: 'Abrir Wise Assistant',
        child: const Icon(Icons.smart_toy_outlined, size: 29),
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
