class ObligationModel {
  final int id;
  final String title;
  final String? description;
  final double amount;
  final String category;
  final DateTime dueDate;
  final String status;
  final DateTime createdAt;
  final DateTime? paidAt;
  final bool isOverdue;

  ObligationModel({
    required this.id,
    required this.title,
    this.description,
    required this.amount,
    required this.category,
    required this.dueDate,
    required this.status,
    required this.createdAt,
    this.paidAt,
    required this.isOverdue,
  });

  factory ObligationModel.fromJson(Map<String, dynamic> json) {
    return ObligationModel(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      amount: (json['amount'] as num).toDouble(),
      category: json['category'],
      dueDate: DateTime.parse(json['due_date']),
      status: json['status'],
      createdAt: DateTime.parse(json['created_at']),
      paidAt: json['paid_at'] != null ? DateTime.parse(json['paid_at']) : null,
      isOverdue: json['is_overdue'] ?? false,
    );
  }

  bool get isPaid => status == 'pagada';

  bool get isPending => status == 'pendiente';

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'amount': amount,
      'category': category,
      'due_date':
          '${dueDate.year.toString().padLeft(4, '0')}-'
          '${dueDate.month.toString().padLeft(2, '0')}-'
          '${dueDate.day.toString().padLeft(2, '0')}',
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'paid_at': paidAt?.toIso8601String(),
      'is_overdue': isOverdue,
    };
  }
}
