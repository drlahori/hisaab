import 'package:flutter/material.dart';

import '../common.dart';
import '../models.dart';
import '../store.dart';

class AccountsScreen extends StatelessWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final balances = {for (final a in store.accounts) a.id: store.balance(a.id)};
        var assets = 0.0;
        var liabilities = 0.0;
        for (final b in balances.values) {
          if (b >= 0) {
            assets += b;
          } else {
            liabilities += -b;
          }
        }
        final groups = <String>[
          ...kAccountGroups,
          ...store.accounts.map((a) => a.group).where((g) => !kAccountGroups.contains(g)).toSet(),
        ];
        return Scaffold(
          appBar: AppBar(title: const Text('Accounts'), centerTitle: true),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(children: [
                  _sum(context, 'Assets', assets, kIncome),
                  _sum(context, 'Liabilities', liabilities, kExpense),
                  _sum(context, 'Total', assets - liabilities,
                      Theme.of(context).colorScheme.onSurface),
                ]),
              ),
              const Divider(height: 1),
              for (final g in groups)
                if (store.accounts.any((a) => a.group == g)) ...[
                  Container(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(children: [
                      Text(g, style: Theme.of(context).textTheme.labelLarge),
                      const Spacer(),
                      Text(money(store.accounts
                          .where((a) => a.group == g)
                          .fold<double>(0, (s, a) => s + (balances[a.id] ?? 0)))),
                    ]),
                  ),
                  for (final a in store.accounts.where((a) => a.group == g))
                    ListTile(
                      title: Text(a.name),
                      subtitle: a.note.isEmpty ? null : Text(a.note),
                      trailing: Text(
                        money(balances[a.id] ?? 0),
                        style: TextStyle(
                          color: (balances[a.id] ?? 0) < 0 ? kExpense : kIncome,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (_) => AccountDetail(accountId: a.id),
                      )),
                    ),
                ],
            ],
          ),
          floatingActionButton: FloatingActionButton(
            heroTag: 'fab-accounts',
            onPressed: () => openAccountEditor(context),
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  Widget _sum(BuildContext context, String label, double v, Color c) => Expanded(
        child: Column(children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          FittedBox(
            child: Text(money(v), style: TextStyle(color: c, fontWeight: FontWeight.w600)),
          ),
        ]),
      );
}

Future<void> openAccountEditor(BuildContext context, {Account? account}) {
  return Navigator.of(context).push(MaterialPageRoute<void>(
    fullscreenDialog: true,
    builder: (_) => AccountEditor(account: account),
  ));
}

class AccountDetail extends StatelessWidget {
  const AccountDetail({super.key, required this.accountId});

  final String accountId;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final a = store.account(accountId);
        if (a == null) {
          return const Scaffold(body: EmptyState(text: 'Account deleted.'));
        }
        final list = store.forAccount(a.id);
        return Scaffold(
          appBar: AppBar(
            title: Text(a.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => openAccountEditor(context, account: a),
              ),
            ],
          ),
          body: DailyList(
            txns: list,
            header: ListTile(
              title: const Text('Balance'),
              subtitle: Text(a.group),
              trailing: Text(money(store.balance(a.id)),
                  style: Theme.of(context).textTheme.titleLarge),
            ),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => openTxnEditor(context, accountId: a.id),
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }
}

class AccountEditor extends StatefulWidget {
  const AccountEditor({super.key, this.account});

  final Account? account;

  @override
  State<AccountEditor> createState() => _AccountEditorState();
}

class _AccountEditorState extends State<AccountEditor> {
  late final _name = TextEditingController(text: widget.account?.name ?? '');
  late final _initial = TextEditingController(
      text: widget.account == null ? '' : amountText(widget.account!.initial));
  late final _note = TextEditingController(text: widget.account?.note ?? '');
  late String _group = widget.account?.group ?? 'Cash';

  @override
  void dispose() {
    _name.dispose();
    _initial.dispose();
    _note.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      toast(context, 'Enter a name');
      return;
    }
    final initial = _initial.text.trim().isEmpty ? 0.0 : parseAmount(_initial.text);
    if (initial == null) {
      toast(context, 'Starting balance is not a number');
      return;
    }
    store.upsertAccount(Account(
      id: widget.account?.id ?? newId(),
      name: name,
      group: _group,
      initial: initial,
      note: _note.text.trim(),
    ));
    Navigator.pop(context);
  }

  Future<void> _delete() async {
    final a = widget.account!;
    final count = store.forAccount(a.id).length;
    final ok = await confirm(
      context,
      'Delete ${a.name}?',
      count == 0
          ? 'This cannot be undone.'
          : 'Its $count transaction${count == 1 ? '' : 's'} will be deleted too. This cannot be undone.',
    );
    if (!ok || !mounted) return;
    store.deleteAccount(a.id);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.account == null ? 'New account' : 'Edit account'),
        actions: [
          if (widget.account != null)
            IconButton(icon: const Icon(Icons.delete_outline), onPressed: _delete),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text('Group', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 4, children: [
          for (final g in kAccountGroups)
            ChoiceChip(
              label: Text(g),
              selected: _group == g,
              onSelected: (_) => setState(() => _group = g),
            ),
        ]),
        const SizedBox(height: 16),
        TextField(
          controller: _name,
          autofocus: widget.account == null,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _initial,
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          inputFormatters: [AmountFormatter(allowNegative: true)],
          decoration: InputDecoration(
            labelText: 'Starting balance',
            helperText: 'Use a minus sign for money you owe, e.g. a card balance',
            prefixText: '${store.currency} ',
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _note,
          decoration: const InputDecoration(labelText: 'Note', border: OutlineInputBorder()),
        ),
      ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            onPressed: _save,
            child: const Text('Save'),
          ),
        ),
      ),
    );
  }
}
