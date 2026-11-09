import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/obligation_model.dart';
import '../services/api_service.dart';

class NotificationsScreen extends StatefulWidget {
  final String token;

  const NotificationsScreen({super.key, required this.token});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<List<ObligationModel>> _obligationsFuture;

  final NumberFormat _moneyFormat = NumberFormat.currency(
    locale: 'es_CO',
    symbol: '\$ ',
    decimalDigits: 2,
  );

  static const Color primaryColor = Color(0xFF7569B5);
  static const Color darkColor = Color(0xFF292638);

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  void _loadNotifications() {
    _obligationsFuture = ApiService.getObligations(token: widget.token)
        .then((data) {
          final List obligations = data['obligations'] ?? [];

          return obligations.map((item) {
            return ObligationModel.fromJson(Map<String, dynamic>.from(item));
          }).toList();
        });
  }

  Future<void> _refreshNotifications() async {
    setState(() {
      _loadNotifications();
    });

    try {
      await _obligationsFuture;
    } catch (_) {
      // El FutureBuilder mostrará el error.
    }
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  String _formatMoney(double amount) {
    return _moneyFormat.format(amount);
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }

  // ==========================================
  // CLASIFICAR NOTIFICACIONES
  // ==========================================

  String _getNotificationType(ObligationModel obligation) {
    final today = _dateOnly(DateTime.now());
    final dueDate = _dateOnly(obligation.dueDate);

    if (dueDate.isBefore(today)) {
      return 'vencida';
    }

    if (dueDate.isAtSameMomentAs(today)) {
      return 'hoy';
    }

    if (dueDate.isAtSameMomentAs(today.add(const Duration(days: 1)))) {
      return 'manana';
    }

    if (!dueDate.isAfter(today.add(const Duration(days: 3)))) {
      return 'proxima';
    }

    return 'ninguna';
  }

  // ==========================================
  // TARJETA DE NOTIFICACION
  // ==========================================

  Widget _buildNotificationCard(ObligationModel obligation, String type) {
    late final Color color;
    late final Color backgroundColor;
    late final IconData icon;
    late final String title;
    late final String message;

    switch (type) {
      case 'vencida':
        color = Colors.red.shade700;
        backgroundColor = Colors.red.shade50;
        icon = Icons.warning_amber_rounded;
        title = 'Pago vencido';
        message = 'Esta obligación tiene un pago pendiente vencido.';
        break;

      case 'hoy':
        color = Colors.deepOrange.shade700;
        backgroundColor = Colors.orange.shade50;
        icon = Icons.today_outlined;
        title = 'Pago para hoy';
        message = 'Recuerda realizar este pago durante el día.';
        break;

      case 'manana':
        color = Colors.orange.shade700;
        backgroundColor = Colors.orange.shade50;
        icon = Icons.event_available_outlined;
        title = 'Pago para mañana';
        message = 'Esta obligación vence mañana.';
        break;

      default:
        color = primaryColor;
        backgroundColor = const Color(0xFFF0EDFA);
        icon = Icons.calendar_month_outlined;
        title = 'Próximo vencimiento';
        message = 'Tienes una obligación próxima a vencer.';
    }

    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(17),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 45,
              height: 45,
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    obligation.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: darkColor,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    message,
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  if (obligation.description != null &&
                      obligation.description!.trim().isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      obligation.description!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                  const SizedBox(height: 9),
                  Wrap(
                    spacing: 12,
                    runSpacing: 5,
                    children: [
                      Text(
                        _formatMoney(obligation.amount),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: darkColor,
                        ),
                      ),
                      Text(
                        'Vence: ${_formatDate(obligation.dueDate)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    obligation.category,
                    style: const TextStyle(fontSize: 11, color: Colors.black45),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // ESTADO SIN NOTIFICACIONES
  // ==========================================

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.notifications_active_outlined,
                size: 45,
                color: Colors.green.shade600,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '¡Todo está al día!',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
                color: darkColor,
              ),
            ),
            const SizedBox(height: 9),
            const Text(
              'No tienes obligaciones vencidas ni pagos próximos.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.black54,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // INTERFAZ PRINCIPAL
  // ==========================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F6FC),
      appBar: AppBar(
        title: const Text(
          'Notificaciones',
          style: TextStyle(fontWeight: FontWeight.bold, color: darkColor),
        ),
        backgroundColor: const Color(0xFFF7F6FC),
        foregroundColor: darkColor,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Actualizar notificaciones',
            onPressed: _refreshNotifications,
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<List<ObligationModel>>(
        future: _obligationsFuture,
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
                      Icons.error_outline,
                      size: 55,
                      color: Colors.redAccent,
                    ),
                    const SizedBox(height: 15),
                    const Text(
                      'No fue posible cargar las notificaciones.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 15),
                    ElevatedButton.icon(
                      onPressed: _refreshNotifications,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Intentar nuevamente'),
                    ),
                  ],
                ),
              ),
            );
          }

          final obligations = snapshot.data ?? [];

          final pendingObligations = obligations.where(
            (item) => item.isPending,
          );

          final notifications = pendingObligations
              .map((item) {
                return MapEntry(item, _getNotificationType(item));
              })
              .where((item) => item.value != 'ninguna')
              .toList();

          notifications.sort((a, b) {
            return a.key.dueDate.compareTo(b.key.dueDate);
          });

          if (notifications.isEmpty) {
            return _buildEmptyState();
          }

          final overdueCount = notifications
              .where((item) => item.value == 'vencida')
              .length;

          return RefreshIndicator(
            onRefresh: _refreshNotifications,
            color: primaryColor,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(19),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8175C4), Color(0xFF62569F)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.notifications_active_outlined,
                        color: Colors.white,
                        size: 35,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Tus alertas financieras',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              '${notifications.length} '
                              '${notifications.length == 1 ? 'notificación pendiente' : 'notificaciones pendientes'}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                if (overdueCount > 0) ...[
                  _buildSectionTitle(
                    'Obligaciones vencidas',
                    overdueCount,
                    Colors.red.shade700,
                  ),
                  const SizedBox(height: 10),
                  ...notifications
                      .where((item) => item.value == 'vencida')
                      .map(
                        (item) => _buildNotificationCard(item.key, item.value),
                      ),
                  const SizedBox(height: 15),
                ],

                _buildSectionTitle(
                  'Próximos pagos',
                  notifications.length - overdueCount,
                  primaryColor,
                ),
                const SizedBox(height: 10),
                ...notifications
                    .where((item) => item.value != 'vencida')
                    .map(
                      (item) => _buildNotificationCard(item.key, item.value),
                    ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title, int count, Color color) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: darkColor,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}
