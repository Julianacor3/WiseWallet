import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/user_model.dart';
import '../models/transaction_model.dart';

class ApiService {
  // ==========================================
  // DIRECCION DEL BACKEND
  // ==========================================

  static String get baseUrl {
    if (kIsWeb) {
      return 'http://127.0.0.1:5000';
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://192.168.1.7:5000';
    }

    return 'http://127.0.0.1:5000';
  }

  // ==========================================
  // MANEJO DE RESPUESTAS
  // ==========================================

  static Map<String, dynamic> _handleResponse(http.Response response) {
    Map<String, dynamic> data;

    try {
      final decoded = jsonDecode(response.body);

      if (decoded is Map<String, dynamic>) {
        data = decoded;
      } else {
        throw const FormatException('Respuesta no valida');
      }
    } catch (_) {
      throw Exception('El servidor devolvio una respuesta no valida.');
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }

    throw Exception(data['message'] ?? 'Error en la solicitud.');
  }

  // ==========================================
  // REGISTRO
  // ==========================================

  static Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'email': email,
        'password': password,
        'confirm_password': confirmPassword,
      }),
    );

    return _handleResponse(response);
  }

  // ==========================================
  // INICIO DE SESION
  // ==========================================

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    return _handleResponse(response);
  }

  // ==========================================
  // CONSULTAR USUARIO AUTENTICADO
  // ==========================================

  static Future<Map<String, dynamic>> getCurrentUser({
    required String token,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/auth/me'),
      headers: {'Authorization': 'Bearer $token'},
    );

    return _handleResponse(response);
  }

  // ==========================================
  // CONSULTAR USUARIO COMO MODELO
  // ==========================================

  static Future<UserModel> getCurrentUserModel({required String token}) async {
    final data = await getCurrentUser(token: token);

    return UserModel.fromJson(Map<String, dynamic>.from(data['user']));
  }

  // ==========================================
  // CONSULTAR PERFIL FINANCIERO
  // ==========================================

  static Future<Map<String, dynamic>> getProfile({
    required String token,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/profile'),
      headers: {'Authorization': 'Bearer $token'},
    );

    return _handleResponse(response);
  }

  // ==========================================
  // GUARDAR O ACTUALIZAR PERFIL FINANCIERO
  // ==========================================

  static Future<Map<String, dynamic>> saveProfile({
    required String token,
    required Map<String, dynamic> profileData,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/api/profile'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(profileData),
    );

    return _handleResponse(response);
  }

  // ==========================================
  // CONSULTAR TRANSACCIONES
  // ==========================================

  static Future<Map<String, dynamic>> getTransactions({
    required String token,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/transactions'),
      headers: {'Authorization': 'Bearer $token'},
    );

    return _handleResponse(response);
  }

  // ==========================================
  // CONSULTAR TRANSACCIONES COMO MODELOS
  // ==========================================

  static Future<List<TransactionModel>> getTransactionsList({
    required String token,
  }) async {
    final data = await getTransactions(token: token);

    final List transactions = data['transactions'] ?? [];

    return transactions.map((transaction) {
      return TransactionModel.fromJson(Map<String, dynamic>.from(transaction));
    }).toList();
  }

  // ==========================================
  // CREAR TRANSACCION
  // ==========================================

  static Future<Map<String, dynamic>> createTransaction({
    required String token,
    required String description,
    required double amount,
    required String category,
    required String transactionType,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/transactions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'description': description,
        'amount': amount,
        'category': category,
        'transaction_type': transactionType,
      }),
    );

    return _handleResponse(response);
  }

  // ==========================================
  // ACTUALIZAR TRANSACCION
  // ==========================================

  static Future<Map<String, dynamic>> updateTransaction({
    required String token,
    required int transactionId,
    required Map<String, dynamic> changes,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/api/transactions/$transactionId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(changes),
    );

    return _handleResponse(response);
  }

  // ==========================================
  // ELIMINAR TRANSACCION
  // ==========================================

  static Future<Map<String, dynamic>> deleteTransaction({
    required String token,
    required int transactionId,
  }) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/api/transactions/$transactionId'),
      headers: {'Authorization': 'Bearer $token'},
    );

    return _handleResponse(response);
  }

  // ==========================================
  // CONSULTAR OBLIGACIONES
  // ==========================================

  static Future<Map<String, dynamic>> getObligations({
    required String token,
    String? status,
  }) async {
    final uri = Uri.parse('$baseUrl/api/obligations')
        .replace(queryParameters: status == null ? null : {'status': status});

    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );

    return _handleResponse(response);
  }

  // ==========================================
  // CREAR OBLIGACION
  // ==========================================

  static Future<Map<String, dynamic>> createObligation({
    required String token,
    required String title,
    String? description,
    required double amount,
    required String category,
    required String dueDate,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/obligations'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'title': title,
        'description': description,
        'amount': amount,
        'category': category,
        'due_date': dueDate,
      }),
    );

    return _handleResponse(response);
  }

  // ==========================================
  // ACTUALIZAR OBLIGACION
  // ==========================================

  static Future<Map<String, dynamic>> updateObligation({
    required String token,
    required int obligationId,
    required Map<String, dynamic> changes,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/api/obligations/$obligationId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(changes),
    );

    return _handleResponse(response);
  }

  // ==========================================
  // ELIMINAR OBLIGACION
  // ==========================================

  static Future<Map<String, dynamic>> deleteObligation({
    required String token,
    required int obligationId,
  }) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/api/obligations/$obligationId'),
      headers: {'Authorization': 'Bearer $token'},
    );

    return _handleResponse(response);
  }
}
