import 'package:flutter/material.dart';

import '../services/api_service.dart';
import 'home_screen.dart';
import 'register_screen.dart';
import 'financial_profile_screen.dart';

class LoginScreen extends StatefulWidget {
  final String? initialEmail;
  final String? notice;

  const LoginScreen({super.key, this.initialEmail, this.notice});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _emailController;
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    _emailController = TextEditingController(text: widget.initialEmail ?? '');

    if (widget.notice != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(widget.notice!)));
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ==========================================
  // INICIAR SESION Y CONSULTAR PERFIL
  // ==========================================

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // 1. AUTENTICAR USUARIO

      final data = await ApiService.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      final token = data['token'] as String;
      final user = Map<String, dynamic>.from(data['user']);

      // 2. CONSULTAR PERFIL FINANCIERO

      final profileData = await ApiService.getProfile(token: token);

      final profile = profileData['profile'];

      if (!mounted) return;

      // 3. VERIFICAR SI EL PERFIL EXISTE

      if (profile == null) {
        // Usuario sin perfil: mostrar cuestionario.

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => FinancialProfileScreen(token: token, user: user),
          ),
        );
      } else {
        // Usuario con perfil: ir al inicio.

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => HomeScreen(token: token, user: user),
          ),
        );
      }
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
  // INTERFAZ DE INICIO DE SESION
  // ==========================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 390),
              child: Column(
                children: [
                  const Text(
                    'Iniciar sesión',
                    style: TextStyle(fontSize: 36, color: Color(0xFF2C3E50)),
                  ),
                  const SizedBox(height: 38),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 55,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F1E4),
                      borderRadius: BorderRadius.circular(42),
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          _loginInput(
                            controller: _emailController,
                            hint: 'Correo electrónico',
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Ingresa tu correo';
                              }

                              return null;
                            },
                          ),
                          _loginInput(
                            controller: _passwordController,
                            hint: 'Contraseña',
                            obscureText: _obscurePassword,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: const Color(0xFFB6B6B6),
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Ingresa tu contraseña';
                              }

                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            height: 46,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFD5D2F0),
                                foregroundColor: const Color(0xFF5F5F68),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25),
                                ),
                              ),
                              child: _isLoading
                                  ? const CircularProgressIndicator()
                                  : const Text(
                                      'Ingresar',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 25),
                  TextButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const RegisterScreen(),
                        ),
                      );
                    },
                    child: const Text(
                      'Crear una cuenta',
                      style: TextStyle(
                        color: Color(0xFFB8B3D9),
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // CAMPO DE ENTRADA
  // ==========================================

  Widget _loginInput({
    required TextEditingController controller,
    required String hint,
    required String? Function(String?) validator,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            offset: const Offset(0, 2),
            blurRadius: 2,
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        validator: validator,
        decoration: InputDecoration(
          hintText: hint,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 13,
          ),
          suffixIcon: suffixIcon,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: const BorderSide(color: Color(0xFFD5D2F0), width: 2),
          ),
        ),
      ),
    );
  }
}
