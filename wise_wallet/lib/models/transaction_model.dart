class TransactionModel {
  final int id;
  final String description;
  final double amount;
  final String category;
  final String transactionType;
  final int userId;

  TransactionModel({
    required this.id,
    required this.description,
    required this.amount,
    required this.category,
    required this.transactionType,
    required this.userId,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'] as int,
      description: json['description'] as String,
      amount: (json['amount'] as num).toDouble(),
      category: json['category'] as String,
      transactionType: json['transaction_type'] as String,
      userId: json['user_id'] as int,
    );
  }
}
