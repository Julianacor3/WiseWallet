import 'package:flutter/material.dart';

import '../services/api_service.dart';
import 'home_screen.dart';

class FinancialProfileScreen extends StatefulWidget {
  final String token;
  final Map<String, dynamic> user;

  const FinancialProfileScreen({
    super.key,
    required this.token,
    required this.user,
  });

  @override
  State<FinancialProfileScreen> createState() => _FinancialProfileScreenState();
}

class _FinancialProfileScreenState extends State<FinancialProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  final _savingsGoalController = TextEditingController();

  String? _occupation;
  String? _financialGoal;
  String? _monthlyIncome;
  String? _monthlyExpenses;
  String? _savingHabit;
  String? _mainChallenge;

  bool _isLoading = false;

  final Color _primaryColor = const Color(0xFFD5D2F0);
  final Color _backgroundColor = const Color(0xFFF5F1E4);
  final Color _textColor = const Color(0xFF2C3E50);

  @override
  void dispose() {
    _savingsGoalController.dispose();
    super.dispose();
  }

  // ==========================================
  // GUARDAR PERFIL FINANCIERO
  // ==========================================

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final profileData = {
        'occupation': _occupation!,
        'financial_goal': _financialGoal!,
        'monthly_income_range': _monthlyIncome!,
        'monthly_expense_range': _monthlyExpenses!,
        'saving_habit': _savingHabit!,
        'main_challenge': _mainChallenge!,
        'savings_goal': _savingsGoalController.text.trim(),
      };

      await ApiService.saveProfile(
        token: widget.token,
        profileData: profileData,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Perfil financiero guardado correctamente'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => HomeScreen(token: widget.token, user: widget.user),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ==========================================
  // CAMPO DESPLEGABLE
  // ==========================================

  Widget _buildDropdown({
    required String title,
    required String hint,
    required String? value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: _textColor,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 9),
          DropdownButtonFormField<String>(
            initialValue: value,
            isExpanded: true,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: _primaryColor, width: 2),
              ),
            ),
            hint: Text(hint),
            items: options.map((option) {
              return DropdownMenuItem<String>(
                value: option,
                child: Text(option, overflow: TextOverflow.ellipsis),
              );
            }).toList(),
            onChanged: onChanged,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Selecciona una opción';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  // ==========================================
  // CAMPO DE TEXTO OPCIONAL
  // ==========================================

  Widget _buildTextField({
    required String title,
    required String hint,
    required TextEditingController controller,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: _textColor,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 9),
        TextFormField(
          controller: controller,
          maxLength: 100,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Colors.white,
            counterText: '',
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // INTERFAZ DEL PERFIL FINANCIERO
  // ==========================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 25),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 550),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.account_balance_wallet_rounded,
                    size: 55,
                    color: Color(0xFFB8B3D9),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    'Conozcamos tus finanzas',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.bold,
                      color: _textColor,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Cuéntanos un poco sobre ti y tus objetivos. '
                    'Esta información nos ayudará a personalizar '
                    'tu experiencia en Wise Wallet.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black54,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _backgroundColor,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildDropdown(
                            title: '1. ¿Cuál es tu ocupación actual?',
                            hint: 'Selecciona tu ocupación',
                            value: _occupation,
                            options: [
                              'Estudiante',
                              'Empleado',
                              'Trabajador independiente',
                              'Desempleado',
                              'Otro',
                            ],
                            onChanged: (value) {
                              setState(() => _occupation = value);
                            },
                          ),
                          _buildDropdown(
                            title:
                                '2. ¿Cuál es tu principal objetivo financiero?',
                            hint: 'Selecciona tu objetivo',
                            value: _financialGoal,
                            options: [
                              'Ahorrar dinero',
                              'Controlar mis gastos',
                              'Pagar mis deudas',
                              'Crear un fondo de emergencia',
                              'Planificar mis finanzas',
                              'Otro',
                            ],
                            onChanged: (value) {
                              setState(() => _financialGoal = value);
                            },
                          ),
                          _buildDropdown(
                            title:
                                '3. ¿Cuál es tu rango de ingresos mensuales?',
                            hint: 'Selecciona un rango',
                            value: _monthlyIncome,
                            options: [
                              'Sin ingresos',
                              'Menos de \$500.000',
                              'Entre \$500.000 y \$1.000.000',
                              'Entre \$1.000.000 y \$2.000.000',
                              'Entre \$2.000.000 y \$4.000.000',
                              'Más de \$4.000.000',
                              'Prefiero no decirlo',
                            ],
                            onChanged: (value) {
                              setState(() => _monthlyIncome = value);
                            },
                          ),
                          _buildDropdown(
                            title: '4. ¿Cuál es tu rango de gastos mensuales?',
                            hint: 'Selecciona un rango',
                            value: _monthlyExpenses,
                            options: [
                              'Menos de \$300.000',
                              'Entre \$300.000 y \$500.000',
                              'Entre \$500.000 y \$1.000.000',
                              'Entre \$1.000.000 y \$2.000.000',
                              'Más de \$2.000.000',
                              'Prefiero no decirlo',
                            ],
                            onChanged: (value) {
                              setState(() => _monthlyExpenses = value);
                            },
                          ),
                          _buildDropdown(
                            title: '5. ¿Cómo describirías tu hábito de ahorro?',
                            hint: 'Selecciona una opción',
                            value: _savingHabit,
                            options: [
                              'Ahorro constantemente',
                              'Ahorro frecuentemente',
                              'Ahorro ocasionalmente',
                              'Casi nunca ahorro',
                              'Actualmente no ahorro',
                            ],
                            onChanged: (value) {
                              setState(() => _savingHabit = value);
                            },
                          ),
                          _buildDropdown(
                            title: '6. ¿Cuál es tu mayor desafío financiero?',
                            hint: 'Selecciona tu desafío',
                            value: _mainChallenge,
                            options: [
                              'Controlar mis gastos',
                              'Ahorrar con constancia',
                              'Organizar mis ingresos',
                              'Reducir mis gastos',
                              'Planificar mis metas',
                              'Otro',
                            ],
                            onChanged: (value) {
                              setState(() => _mainChallenge = value);
                            },
                          ),
                          _buildTextField(
                            title: '7. ¿Tienes una meta de ahorro específica? (Opcional)',
                            hint: 'Ejemplo: Ahorrar \$3.000.000',
                            controller: _savingsGoalController,
                          ),
                          const SizedBox(height: 25),
                          SizedBox(
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _saveProfile,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _primaryColor,
                                foregroundColor: _textColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25),
                                ),
                              ),
                              child: _isLoading
                                  ? const CircularProgressIndicator()
                                  : const Text(
                                      'Guardar y continuar',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Tus respuestas se utilizarán para personalizar '
                    'las funcionalidades de Wise Wallet.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.black45),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
