import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
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
                      leading: AccountAvatar(account: a),
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
              leading: AccountAvatar(account: a, radius: 24),
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
  late String? _emoji = widget.account?.emoji;
  late String? _image = widget.account?.image;

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
      emoji: _emoji,
      image: _image,
    ));
    Navigator.pop(context);
  }

  Account get _preview => Account(
        id: 'preview',
        name: _name.text,
        group: _group,
        emoji: _emoji,
        image: _image,
      );

  Future<void> _pickEmoji() async {
    final e = await pickEmoji(context, current: _emoji ?? kGroupEmoji[_group]);
    if (e != null) setState(() {
      _emoji = e;
      _image = null;
    });
  }

  Future<void> _pickLogo() async {
    try {
      final f = await FilePicker.pickFile(type: FileType.image);
      if (f == null) return;
      final small = await shrinkImage(await f.readAsBytes());
      setState(() => _image = base64Encode(small));
    } catch (e) {
      if (mounted) toast(context, 'Could not use that image: $e');
    }
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
        Center(child: AccountAvatar(account: _preview, radius: 40)),
        const SizedBox(height: 12),
        Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
          OutlinedButton.icon(
            onPressed: _pickEmoji,
            icon: const Icon(Icons.emoji_emotions_outlined),
            label: const Text('Emoji'),
          ),
          OutlinedButton.icon(
            onPressed: _pickLogo,
            icon: const Icon(Icons.image_outlined),
            label: const Text('Upload logo'),
          ),
          if (_emoji != null || _image != null)
            TextButton(
              onPressed: () => setState(() {
                _emoji = null;
                _image = null;
              }),
              child: const Text('Reset'),
            ),
        ]),
        const SizedBox(height: 20),
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

/// Resizes a picked logo to at most 160px wide and returns PNG bytes.
Future<Uint8List> shrinkImage(Uint8List bytes, {int width = 160}) async {
  final codec = await ui.instantiateImageCodec(bytes, targetWidth: width);
  final frame = await codec.getNextFrame();
  final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
  if (data == null) throw Exception('Unsupported image');
  return data.buffer.asUint8List();
}

const _suggestedEmoji = [
  '💵', '🏦', '💳', '🐷', '📈', '🧾', '👛', '💰', '🪙', '💼',
  '📱', '🏠', '🚗', '🎓', '🛒', '💎', '🏧', '💸', '🤝', '⭐',
];

Future<String?> pickEmoji(BuildContext context, {String? current}) {
  return showDialog<String>(
    context: context,
    builder: (ctx) => _EmojiDialog(current: current),
  );
}

class _EmojiDialog extends StatefulWidget {
  const _EmojiDialog({this.current});
  final String? current;

  @override
  State<_EmojiDialog> createState() => _EmojiDialogState();
}

class _EmojiDialogState extends State<_EmojiDialog> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Choose an emoji'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Wrap(spacing: 4, runSpacing: 4, children: [
            for (final e in _suggestedEmoji)
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => Navigator.pop(context, e),
                child: Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: e == widget.current ? scheme.primaryContainer : null,
                  ),
                  child: Text(e, style: const TextStyle(fontSize: 26)),
                ),
              ),
          ]),
          const SizedBox(height: 12),
          TextField(
            controller: _c,
            decoration: const InputDecoration(
              labelText: 'Or type any emoji',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (v) {
              if (v.trim().isNotEmpty) Navigator.pop(context, v.trim());
            },
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final v = _c.text.trim();
            Navigator.pop(context, v.isEmpty ? null : v);
          },
          child: const Text('Use'),
        ),
      ],
    );
  }
}
