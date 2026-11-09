import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/transaction_model.dart';
import '../services/api_service.dart';

class FinancialHistoryScreen extends StatefulWidget {
  final String token;

  const FinancialHistoryScreen({super.key, required this.token});

  @override
  State<FinancialHistoryScreen> createState() => _FinancialHistoryScreenState();
}

class _FinancialHistoryScreenState extends State<FinancialHistoryScreen> {
  late Future<List<TransactionModel>> _transactionsFuture;

  String _selectedFilter = 'todos';

  final NumberFormat _moneyFormat = NumberFormat.currency(
    locale: 'es_CO',
    symbol: '\$ ',
    decimalDigits: 2,
  );

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  void _loadTransactions() {
    _transactionsFuture = ApiService.getTransactionsList(token: widget.token);
  }

  void _refreshTransactions() {
    setState(() {
      _loadTransactions();
    });
  }

  String _formatMoney(double amount) {
    return _moneyFormat.format(amount);
  }

  List<TransactionModel> _filterTransactions(
    List<TransactionModel> transactions,
  ) {
    if (_selectedFilter == 'ingreso') {
      return transactions
          .where((transaction) => transaction.transactionType == 'ingreso')
          .toList();
    }

    if (_selectedFilter == 'gasto') {
      return transactions
          .where((transaction) => transaction.transactionType == 'gasto')
          .toList();
    }

    return transactions;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Historial financiero',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFFD5D2F0),
        actions: [
          IconButton(
            tooltip: 'Actualizar historial',
            onPressed: _refreshTransactions,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<List<TransactionModel>>(
        future: _transactionsFuture,
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
                      size: 60,
                      color: Colors.redAccent,
                    ),
                    const SizedBox(height: 15),
                    const Text(
                      'No fue posible cargar el historial financiero.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16),
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

          final filteredTransactions = _filterTransactions(transactions);

          return RefreshIndicator(
            onRefresh: () async {
              _refreshTransactions();
              await _transactionsFuture;
            },
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'Resumen de movimientos',
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                  ),
                ),
                const SizedBox(height: 7),
                const Text(
                  'Consulta los ingresos y gastos registrados '
                  'en tu cuenta.',
                  style: TextStyle(fontSize: 14, color: Colors.black54),
                ),
                const SizedBox(height: 20),

                // BALANCE GENERAL
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD5D2F0),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Balance de movimientos',
                        style: TextStyle(
                          fontSize: 15,
                          color: Color(0xFF424052),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _formatMoney(balance),
                        style: const TextStyle(
                          fontSize: 27,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF292638),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 15),

                // RESUMEN DE INGRESOS Y GASTOS
                Row(
                  children: [
                    Expanded(
                      child: _buildSummaryCard(
                        title: 'Ingresos',
                        amount: totalIncome,
                        icon: Icons.trending_up,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(width: 12),
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

                const SizedBox(height: 25),

                // FILTROS
                const Text(
                  'Filtrar movimientos',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                  ),
                ),
                const SizedBox(height: 12),

                Wrap(
                  spacing: 8,
                  children: [
                    _buildFilterChip('Todos', 'todos'),
                    _buildFilterChip('Ingresos', 'ingreso'),
                    _buildFilterChip('Gastos', 'gasto'),
                  ],
                ),

                const SizedBox(height: 22),

                // LISTADO
                Text(
                  'Movimientos (${filteredTransactions.length})',
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                  ),
                ),
                const SizedBox(height: 12),

                if (filteredTransactions.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(25),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.receipt_long,
                          size: 45,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          transactions.isEmpty
                              ? 'Todavía no tienes movimientos registrados.'
                              : 'No hay movimientos de este tipo.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                else
                  ...filteredTransactions.map((transaction) {
                    final isIncome = transaction.transactionType == 'ingreso';

                    return Card(
                      elevation: 1,
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 6,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: isIncome
                              ? Colors.green.shade50
                              : Colors.red.shade50,
                          child: Icon(
                            isIncome
                                ? Icons.arrow_downward
                                : Icons.arrow_upward,
                            color: isIncome ? Colors.green : Colors.red,
                          ),
                        ),
                        title: Text(
                          transaction.description,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: Text(
                            '${transaction.category} • '
                            '${isIncome ? 'Ingreso' : 'Gasto'}',
                          ),
                        ),
                        trailing: Text(
                          '${isIncome ? '+' : '-'}'
                          '${_formatMoney(transaction.amount)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isIncome ? Colors.green : Colors.red,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    );
                  }),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final selected = _selectedFilter == value;

    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: const Color(0xFFD5D2F0),
      onSelected: (_) {
        setState(() {
          _selectedFilter = value;
        });
      },
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required double amount,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontSize: 14, color: Colors.grey)),
          const SizedBox(height: 7),
          Text(
            _formatMoney(amount),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
