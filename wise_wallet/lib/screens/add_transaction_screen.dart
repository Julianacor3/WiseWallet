import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/transaction_model.dart';
import '../services/api_service.dart';

class AddTransactionScreen extends StatefulWidget {
  final String token;
  final TransactionModel? transaction;
  final String? initialTransactionType;

  const AddTransactionScreen({
    super.key,
    required this.token,
    this.transaction,
    this.initialTransactionType,
  });

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _descriptionController;
  late final TextEditingController _amountController;

  late String _transactionType;
  late String _category;

  bool _isLoading = false;

  bool get _isEditing => widget.transaction != null;

  final List<String> _categories = [
    'Alimentación',
    'Transporte',
    'Vivienda',
    'Salud',
    'Educación',
    'Entretenimiento',
    'Salario',
    'Otros',
  ];

  @override
  void initState() {
    super.initState();

    final transaction = widget.transaction;

    _descriptionController = TextEditingController(
      text: transaction?.description ?? '',
    );

    _amountController = TextEditingController(
      text: transaction == null
          ? ''
          : NumberFormat('#,##0.00', 'es_CO').format(transaction.amount),
    );

    _transactionType =
        transaction?.transactionType ??
        widget.initialTransactionType ??
        'gasto';

    _category =
        transaction?.category ??
        (_transactionType == 'ingreso' ? 'Salario' : 'Alimentación');
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  double? _parseAmount(String value) {
    final normalized = value.trim().replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(normalized);
  }

  Future<void> _saveTransaction() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final amount = _parseAmount(_amountController.text);

    if (amount == null || amount <= 0) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (_isEditing) {
        await ApiService.updateTransaction(
          token: widget.token,
          transactionId: widget.transaction!.id,
          changes: {
            'description': _descriptionController.text.trim(),
            'amount': amount,
            'category': _category,
            'transaction_type': _transactionType,
          },
        );
      } else {
        await ApiService.createTransaction(
          token: widget.token,
          description: _descriptionController.text.trim(),
          amount: amount,
          category: _category,
          transactionType: _transactionType,
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing
                ? 'Transacción actualizada correctamente.'
                : 'Transacción registrada correctamente.',
          ),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo guardar: $error'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isIncome = _transactionType == 'ingreso';

    final categories = [..._categories];

    if (!categories.contains(_category)) {
      categories.add(_category);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Editar transacción' : 'Nueva transacción',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFFD5D2F0),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isEditing
                    ? 'Actualiza tu movimiento'
                    : 'Registra tu movimiento',
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isEditing
                    ? 'Modifica los datos de esta transacción.'
                    : 'Completa los datos de tu ingreso o gasto.',
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 28),

              const Text(
                'Tipo de transacción',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Ingreso'),
                      selected: isIncome,
                      selectedColor: Colors.green.shade100,
                      onSelected: _isLoading
                          ? null
                          : (_) {
                              setState(() {
                                _transactionType = 'ingreso';
                                _category = 'Salario';
                              });
                            },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Gasto'),
                      selected: !isIncome,
                      selectedColor: Colors.red.shade100,
                      onSelected: _isLoading
                          ? null
                          : (_) {
                              setState(() {
                                _transactionType = 'gasto';
                                _category = 'Alimentación';
                              });
                            },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 22),

              const Text(
                'Descripción',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),

              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  hintText: 'Ej. Pago de salario',
                  prefixIcon: const Icon(Icons.edit),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Ingresa una descripción.';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 20),

              const Text(
                'Valor',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),

              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [ThousandsDecimalFormatter()],
                decoration: InputDecoration(
                  hintText: 'Ej. 150.000,00',
                  prefixText: '\$ ',
                  prefixIcon: const Icon(Icons.attach_money),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  final amount = _parseAmount(value ?? '');

                  if (amount == null || amount <= 0) {
                    return 'Ingresa un valor mayor que cero.';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 20),

              const Text(
                'Categoría',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),

              DropdownButtonFormField<String>(
                key: ValueKey(_category),
                initialValue: _category,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.category),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: categories.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: _isLoading
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() {
                            _category = value;
                          });
                        }
                      },
              ),

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _saveTransaction,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: Text(
                    _isLoading
                        ? 'Guardando...'
                        : _isEditing
                        ? 'Guardar cambios'
                        : 'Guardar transacción',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD5D2F0),
                    foregroundColor: const Color(0xFF292638),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ThousandsDecimalFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String text = newValue.text.replaceAll('.', '');

    text = text.replaceAll(RegExp(r'[^0-9,]'), '');

    final commaIndex = text.indexOf(',');

    if (commaIndex != -1) {
      final integerPart = text.substring(0, commaIndex);
      final decimalPart = text.substring(commaIndex + 1).replaceAll(',', '');

      final formattedInteger = _formatThousands(integerPart);
      final formatted = '$formattedInteger,$decimalPart';

      return TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }

    final formatted = _formatThousands(text);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  String _formatThousands(String value) {
    if (value.isEmpty) return '';

    final buffer = StringBuffer();

    for (int i = 0; i < value.length; i++) {
      if (i > 0 && (value.length - i) % 3 == 0) {
        buffer.write('.');
      }

      buffer.write(value[i]);
    }

    return buffer.toString();
  }
}
