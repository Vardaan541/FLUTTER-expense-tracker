import 'package:cloud_firestore/cloud_firestore.dart';

enum TransactionType { income, expense }

class TransactionEntry {
  TransactionEntry({
    required this.id,
    required this.amount,
    required this.category,
    required this.note,
    required this.date,
    required this.type,
  });

  final String id;
  final double amount;
  final String category;
  final String note;
  final DateTime date;
  final TransactionType type;

  static const List<String> expenseCategories = <String>[
    'Food',
    'Travel',
    'Bills',
    'Shopping',
    'Health',
    'Entertainment',
    'Education',
    'Other',
  ];

  static const List<String> incomeCategories = <String>[
    'Salary',
    'Freelance',
    'Gift',
    'Investment',
    'Other',
  ];

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'amount': amount,
      'category': category,
      'note': note,
      'date': Timestamp.fromDate(date),
      'type': type.name,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  factory TransactionEntry.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final Map<String, dynamic> data = doc.data() ?? <String, dynamic>{};
    final DateTime parsedDate = _parseDateValue(data['date']);
    final String rawType = (data['type'] as String?) ?? 'expense';

    return TransactionEntry(
      id: doc.id,
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      category: (data['category'] as String?) ?? 'Other',
      note: (data['note'] as String?) ?? '',
      date: parsedDate,
      type: rawType == TransactionType.income.name
          ? TransactionType.income
          : TransactionType.expense,
    );
  }

  static DateTime _parseDateValue(dynamic rawDate) {
    if (rawDate is Timestamp) {
      return rawDate.toDate();
    }
    if (rawDate is DateTime) {
      return rawDate;
    }
    if (rawDate is int) {
      return DateTime.fromMillisecondsSinceEpoch(rawDate);
    }
    if (rawDate is String) {
      return DateTime.tryParse(rawDate) ?? DateTime.now();
    }
    return DateTime.now();
  }
}
