import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'models.dart';

/// Single app-wide store. Screens listen to it with ListenableBuilder.
final store = AppStore();

class AppStore extends ChangeNotifier {
  List<Account> accounts = [];
  List<TxCategory> categories = [];
  List<Txn> txns = [];
  Map<String, double> budgets = {}; // categoryId -> monthly budget
  String currency = 'Rs';
  bool symbolFront = true;

  /// 'system', 'light' or 'dark'.
  String theme = 'system';

  /// Automatic backup: 0 = off, otherwise every N days.
  int autoBackupDays = 0;
  DateTime? lastAutoBackup;
  String? lastBackupPath;

  File? _file;
  Future<void> _pending = Future.value();

  // ---------- persistence ----------

  Future<void> load() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/hisaab_data.json');
    _file = file;
    if (await file.exists()) {
      try {
        final map = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        _applyMap(map);
        return;
      } catch (_) {
        // Keep the unreadable file instead of overwriting it.
        await file.copy('${dir.path}/hisaab_data.corrupt.json');
      }
    }
    accounts = defaultAccounts();
    categories = defaultCategories();
    await _write();
  }

  Map<String, dynamic> _toMap() => {
        'app': 'hisaab',
        'version': 1,
        'exportedAt': DateTime.now().toIso8601String(),
        'currency': currency,
        'symbolFront': symbolFront,
        'accounts': accounts.map((a) => a.toJson()).toList(),
        'categories': categories.map((c) => c.toJson()).toList(),
        'txns': txns.map((t) => t.toJson()).toList(),
        'budgets': budgets,
        'theme': theme,
        'autoBackupDays': autoBackupDays,
        'lastAutoBackup': lastAutoBackup?.toIso8601String(),
        'lastBackupPath': lastBackupPath,
      };

  /// Parses everything first, then swaps it in, so a bad file changes nothing.
  void _applyMap(Map<String, dynamic> m) {
    List<Map<String, dynamic>> list(String key) =>
        ((m[key] as List?) ?? const []).cast<Map<String, dynamic>>();

    final newAccounts = list('accounts').map(Account.fromJson).toList();
    final newCategories = list('categories').map(TxCategory.fromJson).toList();
    final newTxns = list('txns').map(Txn.fromJson).toList();
    final newBudgets = <String, double>{};
    final rawBudgets = m['budgets'];
    if (rawBudgets is Map) {
      rawBudgets.forEach((k, v) {
        if (v is num) newBudgets[k.toString()] = v.toDouble();
      });
    }

    accounts = newAccounts;
    categories = newCategories;
    txns = newTxns;
    budgets = newBudgets;
    currency = (m['currency'] as String?) ?? 'Rs';
    symbolFront = (m['symbolFront'] as bool?) ?? true;
    theme = (m['theme'] as String?) ?? 'system';
    autoBackupDays = (m['autoBackupDays'] as num?)?.toInt() ?? 0;
    lastAutoBackup = DateTime.tryParse((m['lastAutoBackup'] as String?) ?? '');
    lastBackupPath = m['lastBackupPath'] as String?;
  }

  Future<void> _write() async {
    final file = _file;
    if (file == null) return;
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(jsonEncode(_toMap()), flush: true);
    await tmp.rename(file.path);
  }

  void _changed() {
    notifyListeners();
    _pending = _pending.then((_) => _write()).catchError((Object e) {
      debugPrint('Save failed: $e');
    });
  }

  // ---------- backup ----------

  String exportJson() => const JsonEncoder.withIndent(' ').convert(_toMap());

  /// Throws FormatException if the text is not a Hisaab backup.
  void importJson(String text) {
    final decoded = jsonDecode(text);
    if (decoded is! Map<String, dynamic> || decoded['app'] != 'hisaab') {
      throw const FormatException('This file is not a Hisaab backup.');
    }
    // Keep this phone's backup settings; only the money data is replaced.
    final days = autoBackupDays, last = lastAutoBackup, path = lastBackupPath, th = theme;
    _applyMap(decoded);
    theme = th;
    autoBackupDays = days;
    lastAutoBackup = last;
    lastBackupPath = path;
    _changed();
  }

  String exportCsv() {
    String q(String s) => '"${s.replaceAll('"', '""')}"';
    final sorted = [...txns]..sort((a, b) => a.date.compareTo(b.date));
    final b = StringBuffer('Date,Type,Account,To Account,Category,Amount,Note\n');
    for (final t in sorted) {
      final d = t.date;
      final date =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      b.writeln([
        date,
        t.type.name,
        q(account(t.accountId)?.name ?? ''),
        q(account(t.toAccountId)?.name ?? ''),
        q(category(t.categoryId)?.name ?? ''),
        t.amount.toString(),
        q(t.note),
      ].join(','));
    }
    return b.toString();
  }

  // ---------- lookups ----------

  Account? account(String? id) {
    if (id == null) return null;
    for (final a in accounts) {
      if (a.id == id) return a;
    }
    return null;
  }

  TxCategory? category(String? id) {
    if (id == null) return null;
    for (final c in categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  List<TxCategory> categoriesOf(TxType type) =>
      categories.where((c) => c.type == type).toList();

  double balance(String accountId) {
    var b = account(accountId)?.initial ?? 0;
    for (final t in txns) {
      switch (t.type) {
        case TxType.income:
          if (t.accountId == accountId) b += t.amount;
        case TxType.expense:
          if (t.accountId == accountId) b -= t.amount;
        case TxType.transfer:
          if (t.accountId == accountId) b -= t.amount;
          if (t.toAccountId == accountId) b += t.amount;
      }
    }
    return b;
  }

  List<Txn> inMonth(DateTime month) {
    final list = txns
        .where((t) => t.date.year == month.year && t.date.month == month.month)
        .toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  List<Txn> forAccount(String accountId) {
    final list = txns
        .where((t) => t.accountId == accountId || t.toAccountId == accountId)
        .toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  static double sum(Iterable<Txn> list, TxType type) {
    var s = 0.0;
    for (final t in list) {
      if (t.type == type) s += t.amount;
    }
    return s;
  }

  // ---------- edits ----------

  void upsertTxn(Txn t) {
    final i = txns.indexWhere((x) => x.id == t.id);
    if (i >= 0) {
      txns[i] = t;
    } else {
      txns.add(t);
    }
    _changed();
  }

  void deleteTxn(String id) {
    txns.removeWhere((t) => t.id == id);
    _changed();
  }

  void upsertAccount(Account a) {
    final i = accounts.indexWhere((x) => x.id == a.id);
    if (i >= 0) {
      accounts[i] = a;
    } else {
      accounts.add(a);
    }
    _changed();
  }

  /// Also removes that account's transactions.
  void deleteAccount(String id) {
    accounts.removeWhere((a) => a.id == id);
    txns.removeWhere((t) => t.accountId == id || t.toAccountId == id);
    _changed();
  }

  void upsertCategory(TxCategory c) {
    final i = categories.indexWhere((x) => x.id == c.id);
    if (i >= 0) {
      categories[i] = c;
    } else {
      categories.add(c);
    }
    _changed();
  }

  void deleteCategory(String id) {
    categories.removeWhere((c) => c.id == id);
    budgets.remove(id);
    _changed();
  }

  void setBudget(String categoryId, double amount) {
    if (amount <= 0) {
      budgets.remove(categoryId);
    } else {
      budgets[categoryId] = amount;
    }
    _changed();
  }

  void setTheme(String value) {
    theme = value;
    _changed();
  }

  void setAutoBackup(int days) {
    autoBackupDays = days;
    _changed();
  }

  void markBackedUp(DateTime when, String path) {
    lastAutoBackup = when;
    lastBackupPath = path;
    _changed();
  }

  void setCurrency(String symbol, bool front) {
    currency = symbol.trim().isEmpty ? 'Rs' : symbol.trim();
    symbolFront = front;
    _changed();
  }
}
