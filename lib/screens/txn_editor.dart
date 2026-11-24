import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../common.dart';
import '../models.dart';
import '../store.dart';

class TxnEditor extends StatefulWidget {
  const TxnEditor({super.key, this.txn, this.initialDate, this.initialAccountId});

  final Txn? txn;
  final DateTime? initialDate;
  final String? initialAccountId;

  @override
  State<TxnEditor> createState() => _TxnEditorState();
}

class _TxnEditorState extends State<TxnEditor> {
  late TxType _type;
  late DateTime _date;
  String? _accountId;
  String? _toAccountId;
  String? _categoryId;
  final _amount = TextEditingController();
  final _note = TextEditingController();

  bool get _editing => widget.txn != null;

  @override
  void initState() {
    super.initState();
    final t = widget.txn;
    if (t != null) {
      _type = t.type;
      _date = t.date;
      _accountId = t.accountId;
      _toAccountId = t.toAccountId;
      _categoryId = t.categoryId;
      _amount.text = NumberFormat('0.##').format(t.amount);
      _note.text = t.note;
    } else {
      _type = TxType.expense;
      final now = DateTime.now();
      final d = widget.initialDate ?? now;
      _date = DateTime(d.year, d.month, d.day, now.hour, now.minute);
      _accountId = widget.initialAccountId ??
          (store.accounts.isEmpty ? null : store.accounts.first.id);
      _defaultCategory();
    }
  }

  void _defaultCategory() {
    final cats = store.categoriesOf(_type);
    _categoryId = cats.isEmpty ? null : cats.first.id;
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d != null) {
      setState(() => _date = DateTime(d.year, d.month, d.day, _date.hour, _date.minute));
    }
  }

  bool _save({required bool again}) {
    final amount = parseAmount(_amount.text);
    String? error;
    if (amount == null || amount <= 0) {
      error = 'Enter an amount';
    } else if (_accountId == null) {
      error = 'Choose an account';
    } else if (_type == TxType.transfer &&
        (_toAccountId == null || _toAccountId == _accountId)) {
      error = 'Choose a different account to transfer to';
    }
    if (error != null) {
      toast(context, error);
      return false;
    }
    store.upsertTxn(Txn(
      id: widget.txn?.id ?? newId(),
      type: _type,
      date: _date,
      amount: amount!,
      accountId: _accountId!,
      toAccountId: _type == TxType.transfer ? _toAccountId : null,
      categoryId: _type == TxType.transfer ? null : _categoryId,
      note: _note.text.trim(),
    ));
    if (again) {
      setState(() {
        _amount.clear();
        _note.clear();
      });
      toast(context, 'Saved');
    } else {
      Navigator.pop(context);
    }
    return true;
  }

  Future<void> _delete() async {
    final ok = await confirm(context, 'Delete transaction?', 'This cannot be undone.');
    if (!ok || !mounted) return;
    store.deleteTxn(widget.txn!.id);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final color = typeColor(_type);
    final cat = store.category(_categoryId);
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Edit' : 'New'),
        actions: [
          if (_editing)
            IconButton(icon: const Icon(Icons.delete_outline), onPressed: _delete),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<TxType>(
            segments: const [
              ButtonSegment(value: TxType.income, label: Text('Income')),
              ButtonSegment(value: TxType.expense, label: Text('Expense')),
              ButtonSegment(value: TxType.transfer, label: Text('Transfer')),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() {
              _type = s.first;
              if (_type != TxType.transfer && store.category(_categoryId)?.type != _type) {
                _defaultCategory();
              }
            }),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amount,
            autofocus: !_editing,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600, color: color),
            decoration: InputDecoration(
              labelText: 'Amount',
              prefixText: '${store.currency} ',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          _Row(
            label: 'Date',
            value: DateFormat('EEE, d MMM yyyy').format(_date),
            onTap: _pickDate,
          ),
          _Row(
            label: _type == TxType.transfer ? 'From' : 'Account',
            value: store.account(_accountId)?.name ?? 'Choose',
            onTap: () async {
              final id = await pickAccount(context);
              if (id != null) setState(() => _accountId = id);
            },
          ),
          if (_type == TxType.transfer)
            _Row(
              label: 'To',
              value: store.account(_toAccountId)?.name ?? 'Choose',
              onTap: () async {
                final id = await pickAccount(context, exclude: _accountId);
                if (id != null) setState(() => _toAccountId = id);
              },
            )
          else
            _Row(
              label: 'Category',
              value: cat == null ? 'Choose' : '${cat.emoji}  ${cat.name}',
              onTap: () async {
                final id = await pickCategory(context, _type);
                if (id != null) setState(() => _categoryId = id);
              },
            ),
          const SizedBox(height: 8),
          TextField(
            controller: _note,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Note',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(children: [
            Expanded(
              flex: 2,
              child: FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                onPressed: () => _save(again: false),
                child: const Text('Save'),
              ),
            ),
            if (!_editing) ...[
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  onPressed: () => _save(again: true),
                  child: const Text('Continue'),
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, required this.onTap});

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      title: Text(label, style: Theme.of(context).textTheme.bodySmall),
      subtitle: Text(value, style: Theme.of(context).textTheme.titleMedium),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
