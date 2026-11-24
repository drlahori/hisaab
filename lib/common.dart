import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'models.dart';
import 'screens/txn_editor.dart';
import 'store.dart';

const kIncome = Color(0xFF2E7D32);
const kExpense = Color(0xFFD84315);
const kTransfer = Color(0xFF607D8B);

const kChartColors = <Color>[
  Color(0xFF0F766E),
  Color(0xFFF59E0B),
  Color(0xFF6366F1),
  Color(0xFFEC4899),
  Color(0xFF10B981),
  Color(0xFFEF4444),
  Color(0xFF3B82F6),
  Color(0xFF8B5CF6),
  Color(0xFF84CC16),
  Color(0xFFF97316),
  Color(0xFF06B6D4),
  Color(0xFF78716C),
];

final _num = NumberFormat('#,##0.##');

String money(double v) {
  final s = _num.format(v.abs());
  final body = store.symbolFront ? '${store.currency} $s' : '$s ${store.currency}';
  return v < 0 ? '-$body' : body;
}

Color typeColor(TxType t) => switch (t) {
      TxType.income => kIncome,
      TxType.expense => kExpense,
      TxType.transfer => kTransfer,
    };

double? parseAmount(String s) => double.tryParse(s.replaceAll(',', '').trim());

/// Amount shown in an input box, e.g. 1500000 -> "1,500,000".
String amountText(double v) => _num.format(v);

/// Adds thousands commas while typing: 1000000 -> 1,000,000. Max 2 decimals.
class AmountFormatter extends TextInputFormatter {
  AmountFormatter({this.allowNegative = false});

  final bool allowNegative;

  static String _group(String digits) {
    final b = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) b.write(',');
      b.write(digits[i]);
    }
    return b.toString();
  }

  static int _significantBefore(String s, int end) {
    var n = 0;
    for (var i = 0; i < end && i < s.length; i++) {
      final c = s[i];
      if (c == '.' || c == '-' || (c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57)) n++;
    }
    return n;
  }

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final raw = newValue.text;
    var negative = false;
    var intDigits = StringBuffer();
    var decDigits = StringBuffer();
    var seenDot = false;
    for (var i = 0; i < raw.length; i++) {
      final c = raw[i];
      final code = c.codeUnitAt(0);
      if (c == '-' && allowNegative && i == 0) {
        negative = true;
      } else if (c == '.') {
        seenDot = true;
      } else if (code >= 48 && code <= 57) {
        if (!seenDot) {
          intDigits.write(c);
        } else if (decDigits.length < 2) {
          decDigits.write(c);
        }
      }
    }
    var ints = intDigits.toString().replaceFirst(RegExp(r'^0+(?=\d)'), '');
    if (ints.isEmpty && seenDot) ints = '0';
    final text = '${negative ? '-' : ''}${_group(ints)}${seenDot ? '.$decDigits' : ''}';

    // Keep the cursor after the same number of digits as before.
    final want = _significantBefore(raw, newValue.selection.baseOffset < 0 ? raw.length : newValue.selection.baseOffset);
    var offset = text.length;
    var count = 0;
    for (var i = 0; i < text.length; i++) {
      if (count >= want) {
        offset = i;
        break;
      }
      if (text[i] != ',') count++;
    }
    if (count < want) offset = text.length;
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: offset));
  }
}

Future<void> openTxnEditor(BuildContext context,
    {Txn? txn, DateTime? date, String? accountId}) {
  return Navigator.of(context).push(MaterialPageRoute<void>(
    fullscreenDialog: true,
    builder: (_) => TxnEditor(txn: txn, initialDate: date, initialAccountId: accountId),
  ));
}

/// "< Nov 2026 >" switcher used on several screens.
class MonthSwitcher extends StatelessWidget {
  const MonthSwitcher({super.key, required this.month, required this.onChanged, this.yearOnly = false});

  final DateTime month;
  final ValueChanged<DateTime> onChanged;
  final bool yearOnly;

  @override
  Widget build(BuildContext context) {
    final step = yearOnly ? 12 : 1;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => onChanged(DateTime(month.year, month.month - step)),
        ),
        Text(
          yearOnly ? '${month.year}' : DateFormat('MMM yyyy').format(month),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: () => onChanged(DateTime(month.year, month.month + step)),
        ),
      ],
    );
  }
}

class SummaryBar extends StatelessWidget {
  const SummaryBar({super.key, required this.income, required this.expense});

  final double income;
  final double expense;

  @override
  Widget build(BuildContext context) {
    Widget cell(String label, double v, Color c) => Expanded(
          child: Column(
            children: [
              Text(label, style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 2),
              FittedBox(
                child: Text(money(v),
                    style: TextStyle(color: c, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(children: [
        cell('Income', income, kIncome),
        cell('Expenses', expense, kExpense),
        cell('Total', income - expense, Theme.of(context).colorScheme.onSurface),
      ]),
    );
  }
}

class AccountAvatar extends StatelessWidget {
  const AccountAvatar({super.key, required this.account, this.radius = 20});

  final Account account;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final bytes = account.imageBytes;
    if (bytes != null) {
      return Container(
        width: radius * 2,
        height: radius * 2,
        padding: EdgeInsets.all(radius * 0.18),
        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        child: ClipOval(child: Image.memory(bytes, fit: BoxFit.contain, gaplessPlayback: true)),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Text(account.shownEmoji, style: TextStyle(fontSize: radius * 0.95)),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.text, this.icon = Icons.receipt_long});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.outline;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 48, color: muted),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center, style: TextStyle(color: muted)),
        ]),
      ),
    );
  }
}

class TxnTile extends StatelessWidget {
  const TxnTile({super.key, required this.txn});

  final Txn txn;

  @override
  Widget build(BuildContext context) {
    final cat = store.category(txn.categoryId);
    final acc = store.account(txn.accountId)?.name ?? '?';
    final String title;
    final String emoji;
    final String accText;
    if (txn.type == TxType.transfer) {
      title = 'Transfer';
      emoji = '🔁';
      accText = '$acc → ${store.account(txn.toAccountId)?.name ?? '?'}';
    } else {
      title = cat?.name ?? 'Uncategorised';
      emoji = cat?.emoji ?? '❔';
      accText = acc;
    }
    final subtitle = txn.note.isEmpty ? accText : '${txn.note} · $accText';
    return ListTile(
      dense: true,
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Text(emoji, style: const TextStyle(fontSize: 18)),
      ),
      title: Text(title),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Text(
        money(txn.amount),
        style: TextStyle(color: typeColor(txn.type), fontWeight: FontWeight.w600),
      ),
      onTap: () => openTxnEditor(context, txn: txn),
    );
  }
}

/// Transactions grouped by day, newest first.
class DailyList extends StatelessWidget {
  const DailyList({super.key, required this.txns, this.header});

  final List<Txn> txns;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    if (txns.isEmpty) {
      return ListView(children: [
        if (header != null) header!,
        const SizedBox(height: 60),
        const EmptyState(text: 'No transactions yet.\nTap + to add one.'),
      ]);
    }
    final days = <DateTime, List<Txn>>{};
    for (final t in txns) {
      final d = DateTime(t.date.year, t.date.month, t.date.day);
      days.putIfAbsent(d, () => []).add(t);
    }
    final keys = days.keys.toList()..sort((a, b) => b.compareTo(a));
    final extra = header == null ? 0 : 1;
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 96),
      itemCount: keys.length + extra,
      itemBuilder: (context, i) {
        if (header != null && i == 0) return header!;
        final day = keys[i - extra];
        final list = days[day]!;
        return Card(
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          clipBehavior: Clip.antiAlias,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Row(children: [
                Text('${day.day}',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Text(DateFormat('EEE, MMM yyyy').format(day),
                    style: Theme.of(context).textTheme.bodySmall),
                const Spacer(),
                Text(money(AppStore.sum(list, TxType.income)),
                    style: const TextStyle(color: kIncome, fontSize: 12)),
                const SizedBox(width: 10),
                Text(money(AppStore.sum(list, TxType.expense)),
                    style: const TextStyle(color: kExpense, fontSize: 12)),
              ]),
            ),
            const Divider(height: 1),
            for (final t in list) TxnTile(txn: t),
          ]),
        );
      },
    );
  }
}

// ---------- pickers & dialogs ----------

Future<String?> pickAccount(BuildContext context, {String? exclude}) {
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
        child: ListView(shrinkWrap: true, children: [
          for (final a in store.accounts.where((a) => a.id != exclude))
            ListTile(
              leading: AccountAvatar(account: a),
              title: Text(a.name),
              subtitle: Text(a.group),
              trailing: Text(money(store.balance(a.id))),
              onTap: () => Navigator.pop(ctx, a.id),
            ),
        ]),
      ),
    ),
  );
}

Future<String?> pickCategory(BuildContext context, TxType type) {
  final cats = store.categoriesOf(type);
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in cats)
              ActionChip(
                avatar: Text(c.emoji),
                label: Text(c.name),
                onPressed: () => Navigator.pop(ctx, c.id),
              ),
          ],
        ),
      ),
    ),
  );
}

Future<bool> confirm(BuildContext context, String title, String message,
    {String action = 'Delete'}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(action)),
      ],
    ),
  );
  return ok ?? false;
}

Future<String?> promptText(BuildContext context, String title,
    {String initial = '', String hint = '', bool number = false}) {
  return showDialog<String>(
    context: context,
    builder: (ctx) => _PromptDialog(title: title, initial: initial, hint: hint, number: number),
  );
}

class _PromptDialog extends StatefulWidget {
  const _PromptDialog(
      {required this.title, required this.initial, required this.hint, required this.number});

  final String title;
  final String initial;
  final String hint;
  final bool number;

  @override
  State<_PromptDialog> createState() => _PromptDialogState();
}

class _PromptDialogState extends State<_PromptDialog> {
  late final TextEditingController _c = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _c,
        autofocus: true,
        keyboardType: widget.number
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        inputFormatters: widget.number ? [AmountFormatter()] : null,
        decoration: InputDecoration(hintText: widget.hint),
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, _c.text), child: const Text('OK')),
      ],
    );
  }
}

void toast(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}
