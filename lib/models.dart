import 'dart:math';

enum TxType { income, expense, transfer }

TxType txTypeFrom(String? s) {
  for (final t in TxType.values) {
    if (t.name == s) return t;
  }
  return TxType.expense;
}

final _rand = Random();
String newId() =>
    '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${_rand.nextInt(1 << 30).toRadixString(36)}';

const kAccountGroups = <String>[
  'Cash',
  'Bank',
  'Card',
  'Savings',
  'Investments',
  'Loan',
  'Other',
];

double _d(Object? v) => v is num ? v.toDouble() : 0;

class Account {
  Account({
    required this.id,
    required this.name,
    this.group = 'Cash',
    this.initial = 0,
    this.note = '',
  });

  final String id;
  String name;
  String group;
  double initial;
  String note;

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'group': group, 'initial': initial, 'note': note};

  factory Account.fromJson(Map<String, dynamic> j) => Account(
        id: j['id'] as String,
        name: (j['name'] as String?) ?? '',
        group: (j['group'] as String?) ?? 'Cash',
        initial: _d(j['initial']),
        note: (j['note'] as String?) ?? '',
      );
}

class TxCategory {
  TxCategory({
    required this.id,
    required this.name,
    required this.type,
    this.emoji = '📦',
  });

  final String id;
  String name;
  TxType type;
  String emoji;

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'type': type.name, 'emoji': emoji};

  factory TxCategory.fromJson(Map<String, dynamic> j) => TxCategory(
        id: j['id'] as String,
        name: (j['name'] as String?) ?? '',
        type: txTypeFrom(j['type'] as String?),
        emoji: (j['emoji'] as String?) ?? '📦',
      );
}

class Txn {
  Txn({
    required this.id,
    required this.type,
    required this.date,
    required this.amount,
    required this.accountId,
    this.toAccountId,
    this.categoryId,
    this.note = '',
  });

  final String id;
  TxType type;
  DateTime date;
  double amount;
  String accountId;
  String? toAccountId;
  String? categoryId;
  String note;

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'date': date.toIso8601String(),
        'amount': amount,
        'accountId': accountId,
        'toAccountId': toAccountId,
        'categoryId': categoryId,
        'note': note,
      };

  factory Txn.fromJson(Map<String, dynamic> j) => Txn(
        id: j['id'] as String,
        type: txTypeFrom(j['type'] as String?),
        date: DateTime.tryParse((j['date'] as String?) ?? '') ?? DateTime.now(),
        amount: _d(j['amount']),
        accountId: (j['accountId'] as String?) ?? '',
        toAccountId: j['toAccountId'] as String?,
        categoryId: j['categoryId'] as String?,
        note: (j['note'] as String?) ?? '',
      );
}

List<Account> defaultAccounts() => [
      Account(id: newId(), name: 'Cash', group: 'Cash'),
      Account(id: newId(), name: 'Bank Account', group: 'Bank'),
      Account(id: newId(), name: 'Card', group: 'Card'),
    ];

List<TxCategory> defaultCategories() {
  TxCategory c(String name, String emoji, TxType t) =>
      TxCategory(id: newId(), name: name, type: t, emoji: emoji);
  const e = TxType.expense;
  const i = TxType.income;
  return [
    c('Food', '🍔', e),
    c('Transport', '🚗', e),
    c('Shopping', '🛍️', e),
    c('Bills', '🧾', e),
    c('Rent', '🏠', e),
    c('Health', '💊', e),
    c('Education', '🎓', e),
    c('Entertainment', '🎬', e),
    c('Gifts', '🎁', e),
    c('Other', '📦', e),
    c('Salary', '💼', i),
    c('Freelance', '💻', i),
    c('Business', '📈', i),
    c('Gifts', '🎁', i),
    c('Other', '💰', i),
  ];
}
