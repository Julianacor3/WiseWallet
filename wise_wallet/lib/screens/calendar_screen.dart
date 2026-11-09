import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../models/obligation_model.dart';
import '../services/api_service.dart';

class CalendarScreen extends StatefulWidget {
  final String token;

  const CalendarScreen({super.key, required this.token});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late Future<List<ObligationModel>> _obligationsFuture;

  DateTime _selectedDate = DateTime.now();

  DateTime _displayedMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
  );

  String _selectedStatus = 'todas';

  final NumberFormat _moneyFormat = NumberFormat.currency(
    locale: 'es_CO',
    symbol: '\$ ',
    decimalDigits: 2,
  );

  final List<String> _categories = [
    'Servicios públicos',
    'Vivienda',
    'Educación',
    'Salud',
    'Transporte',
    'Alimentación',
    'Entretenimiento',
    'Tarjetas de crédito',
    'Préstamos',
    'Impuestos',
    'Otros',
  ];

  static const Color _primaryColor = Color(0xFF6255A5);
  static const Color _pendingColor = Colors.orange;
  static const Color _paidColor = Colors.green;
  static const Color _overdueColor = Colors.red;

  @override
  void initState() {
    super.initState();
    _loadObligations();
  }

  // ==========================================
  // CARGAR OBLIGACIONES
  // ==========================================

  void _loadObligations() {
    _obligationsFuture = initializeDateFormatting('es_CO')
        .then((_) {
          return ApiService.getObligations(token: widget.token);
        })
        .then((data) {
          final List obligations = data['obligations'] ?? [];

          return obligations.map((obligation) {
            return ObligationModel.fromJson(
              Map<String, dynamic>.from(obligation),
            );
          }).toList();
        });
  }

  void _refreshObligations() {
    setState(() {
      _loadObligations();
    });
  }

  String _formatMoney(double amount) {
    return _moneyFormat.format(amount);
  }

  bool _sameDay(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  List<ObligationModel> _obligationsForDay(
    List<ObligationModel> obligations,
    DateTime date,
  ) {
    return obligations.where((obligation) {
      return _sameDay(obligation.dueDate, date);
    }).toList();
  }

  List<ObligationModel> _filterObligations(List<ObligationModel> obligations) {
    return obligations.where((obligation) {
      final matchesDate = _sameDay(obligation.dueDate, _selectedDate);

      final matchesStatus =
          _selectedStatus == 'todas' || obligation.status == _selectedStatus;

      return matchesDate && matchesStatus;
    }).toList();
  }

  // ==========================================
  // COLORES DE LOS INDICADORES
  // ==========================================

  Color _indicatorColor(ObligationModel obligation) {
    if (obligation.isPaid) return _paidColor;
    if (obligation.isOverdue) return _overdueColor;
    return _pendingColor;
  }

  // ==========================================
  // CAMBIAR DE MES
  // ==========================================

  void _changeMonth(int difference) {
    setState(() {
      _displayedMonth = DateTime(
        _displayedMonth.year,
        _displayedMonth.month + difference,
      );
    });
  }

  // ==========================================
  // CALENDARIO PERSONALIZADO COMPACTO
  // ==========================================

  Widget _buildMonthCalendar(List<ObligationModel> obligations) {
    final firstDay = DateTime(_displayedMonth.year, _displayedMonth.month, 1);

    final daysInMonth = DateUtils.getDaysInMonth(
      _displayedMonth.year,
      _displayedMonth.month,
    );

    final startingWeekday = firstDay.weekday - 1;
    final today = DateTime.now();

    final monthName = DateFormat('MMMM yyyy', 'es_CO').format(_displayedMonth);

    final calendarCells = List.generate(42, (index) {
      final dayNumber = index - startingWeekday + 1;

      if (dayNumber < 1 || dayNumber > daysInMonth) {
        return const SizedBox.shrink();
      }

      final date = DateTime(
        _displayedMonth.year,
        _displayedMonth.month,
        dayNumber,
      );

      final isSelected = _sameDay(date, _selectedDate);
      final isToday = _sameDay(date, today);

      final dayObligations = _obligationsForDay(obligations, date);

      return InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: () {
          setState(() {
            _selectedDate = date;
          });
        },
        child: Container(
          margin: const EdgeInsets.all(1),
          decoration: BoxDecoration(
            color: isSelected ? _primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            border: isToday && !isSelected
                ? Border.all(color: _primaryColor, width: 1.3)
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$dayNumber',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected || isToday
                      ? FontWeight.bold
                      : FontWeight.normal,
                  color: isSelected ? Colors.white : const Color(0xFF2C3E50),
                ),
              ),
              const SizedBox(height: 3),

              // Indicadores de obligaciones.
              SizedBox(
                height: 6,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: dayObligations.take(3).map((obligation) {
                    return Container(
                      width: 5,
                      height: 5,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white
                            : _indicatorColor(obligation),
                        shape: BoxShape.circle,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      );
    });

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Card(
          elevation: 1,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                // Encabezado del mes.
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Mes anterior',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _changeMonth(-1),
                      icon: const Icon(Icons.chevron_left),
                      color: _primaryColor,
                    ),
                    Expanded(
                      child: Text(
                        monthName[0].toUpperCase() + monthName.substring(1),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Mes siguiente',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _changeMonth(1),
                      icon: const Icon(Icons.chevron_right),
                      color: _primaryColor,
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                // Días de la semana.
                Row(
                  children: ['L', 'M', 'X', 'J', 'V', 'S', 'D'].map((day) {
                    return Expanded(
                      child: Center(
                        child: Text(
                          day,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 5),

                // Cuadrícula compacta.
                GridView.count(
                  crossAxisCount: 7,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.15,
                  children: calendarCells,
                ),

                const SizedBox(height: 8),

                // Leyenda.
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  alignment: WrapAlignment.center,
                  children: [
                    _buildLegendItem(_pendingColor, 'Pendiente'),
                    _buildLegendItem(_overdueColor, 'Vencida'),
                    _buildLegendItem(_paidColor, 'Pagada'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // LEYENDA DEL CALENDARIO
  // ==========================================

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ],
    );
  }

  // ==========================================
  // CREAR Y EDITAR OBLIGACIONES
  // ==========================================

  Future<void> _showObligationForm({ObligationModel? obligation}) async {
    final isEditing = obligation != null;

    final titleController = TextEditingController(
      text: obligation?.title ?? '',
    );

    final descriptionController = TextEditingController(
      text: obligation?.description ?? '',
    );

    final amountController = TextEditingController(
      text: obligation?.amount.toString() ?? '',
    );

    final formKey = GlobalKey<FormState>();

    DateTime dueDate = obligation?.dueDate ?? _selectedDate;

    String selectedCategory = obligation?.category ?? _categories.first;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        bool isSaving = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                isEditing ? 'Editar obligación' : 'Nueva obligación',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SizedBox(
                width: 450,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: titleController,
                          decoration: const InputDecoration(
                            labelText: 'Título',
                            hintText: 'Ej. Pago de energía',
                            prefixIcon: Icon(Icons.title),
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Ingresa el título de la obligación.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 15),
                        TextFormField(
                          controller: descriptionController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Descripción (opcional)',
                            prefixIcon: Icon(Icons.description_outlined),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 15),
                        TextFormField(
                          controller: amountController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Valor',
                            hintText: 'Ej. 120000',
                            prefixIcon: Icon(Icons.attach_money),
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            final amount = double.tryParse(
                              (value ?? '').trim().replaceAll(',', '.'),
                            );

                            if (amount == null || !amount.isFinite) {
                              return 'Ingresa un valor válido.';
                            }

                            if (amount <= 0) {
                              return 'El valor debe ser mayor que cero.';
                            }

                            return null;
                          },
                        ),
                        const SizedBox(height: 15),
                        DropdownButtonFormField<String>(
                          initialValue: _categories.contains(selectedCategory)
                              ? selectedCategory
                              : 'Otros',
                          decoration: const InputDecoration(
                            labelText: 'Categoría',
                            prefixIcon: Icon(Icons.category_outlined),
                            border: OutlineInputBorder(),
                          ),
                          items: _categories.map((category) {
                            return DropdownMenuItem(
                              value: category,
                              child: Text(category),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setDialogState(() {
                                selectedCategory = value;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 15),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0EEFA),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Fecha de vencimiento',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.calendar_month,
                                    color: Color(0xFF6255A5),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      DateFormat('dd/MM/yyyy').format(dueDate),
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () async {
                                      final selected = await showDatePicker(
                                        context: dialogContext,
                                        initialDate: dueDate,
                                        firstDate: DateTime(2020),
                                        lastDate: DateTime(2100),
                                      );

                                      if (selected != null) {
                                        setDialogState(() {
                                          dueDate = selected;
                                        });
                                      }
                                    },
                                    child: const Text('Cambiar'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton.icon(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) {
                            return;
                          }

                          setDialogState(() {
                            isSaving = true;
                          });

                          try {
                            final amount = double.parse(
                              amountController.text.trim().replaceAll(',', '.'),
                            );

                            final dateString =
                                '${dueDate.year.toString().padLeft(4, '0')}-'
                                '${dueDate.month.toString().padLeft(2, '0')}-'
                                '${dueDate.day.toString().padLeft(2, '0')}';

                            final description =
                                descriptionController.text.trim().isEmpty
                                ? null
                                : descriptionController.text.trim();

                            if (isEditing) {
                              await ApiService.updateObligation(
                                token: widget.token,
                                obligationId: obligation.id,
                                changes: {
                                  'title': titleController.text.trim(),
                                  'description': description,
                                  'amount': amount,
                                  'category': selectedCategory,
                                  'due_date': dateString,
                                },
                              );
                            } else {
                              await ApiService.createObligation(
                                token: widget.token,
                                title: titleController.text.trim(),
                                description: description,
                                amount: amount,
                                category: selectedCategory,
                                dueDate: dateString,
                              );
                            }

                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext, true);
                            }
                          } catch (error) {
                            setDialogState(() {
                              isSaving = false;
                            });

                            if (dialogContext.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('No se pudo guardar: $error'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                  icon: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save),
                  label: Text(isSaving ? 'Guardando...' : 'Guardar'),
                ),
              ],
            );
          },
        );
      },
    );

    titleController.dispose();
    descriptionController.dispose();
    amountController.dispose();

    if (result == true && mounted) {
      _refreshObligations();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEditing
                ? 'Obligación actualizada correctamente.'
                : 'Obligación registrada correctamente.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  // ==========================================
  // ESTADOS DE LAS OBLIGACIONES
  // ==========================================

  Color _statusColor(ObligationModel obligation) {
    if (obligation.isPaid) return _paidColor;
    if (obligation.isOverdue) return _overdueColor;
    return _pendingColor;
  }

  String _statusText(ObligationModel obligation) {
    if (obligation.isPaid) return 'Pagada';
    if (obligation.isOverdue) return 'Vencida';
    return 'Pendiente';
  }

  // ==========================================
  // MARCAR COMO PAGADA
  // ==========================================

  Future<void> _markAsPaid(ObligationModel obligation) async {
    try {
      await ApiService.updateObligation(
        token: widget.token,
        obligationId: obligation.id,
        changes: {'status': 'pagada'},
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Obligación marcada como pagada.'),
          backgroundColor: Colors.green,
        ),
      );

      _refreshObligations();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo actualizar: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ==========================================
  // ELIMINAR OBLIGACIÓN
  // ==========================================

  Future<void> _deleteObligation(ObligationModel obligation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Eliminar obligación'),
          content: Text('¿Deseas eliminar "${obligation.title}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    try {
      await ApiService.deleteObligation(
        token: widget.token,
        obligationId: obligation.id,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Obligación eliminada correctamente.'),
          backgroundColor: Colors.green,
        ),
      );

      _refreshObligations();
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
  // TARJETA DE OBLIGACIÓN
  // ==========================================

  Widget _buildObligationCard(ObligationModel obligation) {
    final color = _statusColor(obligation);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(
            obligation.isPaid ? Icons.check_circle_outline : Icons.event_note,
            color: color,
          ),
        ),
        title: Text(
          obligation.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 5),
            Text(obligation.category),
            if (obligation.description != null &&
                obligation.description!.isNotEmpty)
              Text(obligation.description!),
            const SizedBox(height: 5),
            Text(
              _statusText(obligation),
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _formatMoney(obligation.amount),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
                fontSize: 13,
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Opciones',
              onSelected: (value) {
                if (value == 'editar') {
                  _showObligationForm(obligation: obligation);
                } else if (value == 'pagar') {
                  _markAsPaid(obligation);
                } else if (value == 'eliminar') {
                  _deleteObligation(obligation);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'editar',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 20),
                      SizedBox(width: 8),
                      Text('Editar'),
                    ],
                  ),
                ),
                if (!obligation.isPaid)
                  const PopupMenuItem(
                    value: 'pagar',
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_outline, size: 20),
                        SizedBox(width: 8),
                        Text('Marcar como pagada'),
                      ],
                    ),
                  ),
                const PopupMenuItem(
                  value: 'eliminar',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, size: 20),
                      SizedBox(width: 8),
                      Text('Eliminar'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  // ==========================================
  // INTERFAZ PRINCIPAL
  // ==========================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Calendario de pagos',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFFD5D2F0),
        actions: [
          IconButton(
            tooltip: 'Actualizar obligaciones',
            onPressed: _refreshObligations,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showObligationForm(),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Agregar obligación'),
      ),
      body: FutureBuilder<List<ObligationModel>>(
        future: _obligationsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
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
                      color: Colors.redAccent,
                      size: 55,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No fue posible cargar las obligaciones.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 15),
                    ElevatedButton.icon(
                      onPressed: _refreshObligations,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Intentar nuevamente'),
                    ),
                  ],
                ),
              ),
            );
          }

          final obligations = snapshot.data ?? [];

          final filteredObligations = _filterObligations(obligations);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            children: [
              const Text(
                'Mis obligaciones',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'Consulta tus fechas de pago y mantén tus compromisos al día.',
                style: TextStyle(fontSize: 13, color: Colors.black54),
              ),
              const SizedBox(height: 15),

              // Calendario compacto y centrado.
              _buildMonthCalendar(obligations),

              const SizedBox(height: 22),

              Text(
                'Obligaciones del '
                '${DateFormat('dd/MM/yyyy').format(_selectedDate)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                ),
              ),

              const SizedBox(height: 12),

              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'todas', label: Text('Todas')),
                  ButtonSegment(value: 'pendiente', label: Text('Pendientes')),
                  ButtonSegment(value: 'pagada', label: Text('Pagadas')),
                ],
                selected: {_selectedStatus},
                onSelectionChanged: (selection) {
                  setState(() {
                    _selectedStatus = selection.first;
                  });
                },
              ),

              const SizedBox(height: 18),

              if (filteredObligations.isEmpty)
                Container(
                  padding: const EdgeInsets.all(25),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.event_available, size: 45, color: Colors.grey),
                      SizedBox(height: 10),
                      Text(
                        'No tienes obligaciones para esta fecha.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              else
                ...filteredObligations.map(_buildObligationCard),
            ],
          );
        },
      ),
    );
  }
}
