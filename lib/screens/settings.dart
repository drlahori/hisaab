import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../common.dart';
import '../models.dart';
import '../store.dart';
import 'budgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('More'), centerTitle: true),
        body: ListView(children: [
          const _Header('Backup'),
          Builder(
            builder: (ctx) => ListTile(
              leading: const Icon(Icons.cloud_upload_outlined),
              title: const Text('Back up now'),
              subtitle: const Text('Save to Google Drive, Gmail, iCloud, Files…'),
              onTap: () => _backup(ctx),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('Restore from backup'),
            subtitle: const Text('Pick a Hisaab backup file'),
            onTap: () => _restore(context),
          ),
          Builder(
            builder: (ctx) => ListTile(
              leading: const Icon(Icons.table_chart_outlined),
              title: const Text('Export to Excel (CSV)'),
              onTap: () => _exportCsv(ctx),
            ),
          ),
          const _Header('Settings'),
          ListTile(
            leading: const Icon(Icons.payments_outlined),
            title: const Text('Currency'),
            trailing: Text(money(1234.5)),
            onTap: () => _currency(context),
          ),
          ListTile(
            leading: const Icon(Icons.category_outlined),
            title: const Text('Categories'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const CategoriesScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.savings_outlined),
            title: const Text('Budgets'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const BudgetsScreen()),
            ),
          ),
          const _Header('About'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Hisaab 1.0'),
            subtitle: Text('No ads. Your data stays on your phone and in backups you choose.'),
          ),
        ]),
      ),
    );
  }

  Rect? _origin(BuildContext context) {
    final box = context.findRenderObject();
    if (box is RenderBox && box.hasSize) {
      return box.localToGlobal(Offset.zero) & box.size;
    }
    return null;
  }

  Future<void> _shareFile(BuildContext context, String name, String content, String mime,
      String subject) async {
    final origin = _origin(context);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$name');
    await file.writeAsString(content, flush: true);
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path, mimeType: mime)],
      subject: subject,
      sharePositionOrigin: origin,
    ));
  }

  String get _stamp => DateFormat('yyyy-MM-dd_HHmm').format(DateTime.now());

  Future<void> _backup(BuildContext context) async {
    try {
      await _shareFile(context, 'hisaab-backup-$_stamp.json', store.exportJson(),
          'application/json', 'Hisaab backup');
    } catch (e) {
      if (context.mounted) toast(context, 'Backup failed: $e');
    }
  }

  Future<void> _exportCsv(BuildContext context) async {
    try {
      await _shareFile(context, 'hisaab-$_stamp.csv', store.exportCsv(), 'text/csv',
          'Hisaab transactions');
    } catch (e) {
      if (context.mounted) toast(context, 'Export failed: $e');
    }
  }

  Future<void> _restore(BuildContext context) async {
    try {
      final res = await FilePicker.platform.pickFiles(type: FileType.any, withData: true);
      if (res == null || res.files.isEmpty) return;
      final f = res.files.single;
      List<int>? bytes = f.bytes;
      if (bytes == null && f.path != null) bytes = await File(f.path!).readAsBytes();
      if (bytes == null) throw const FormatException('Could not read the file.');
      final text = utf8.decode(bytes);
      if (!context.mounted) return;
      final ok = await confirm(
        context,
        'Restore this backup?',
        'All data currently in the app will be replaced by the backup.',
        action: 'Restore',
      );
      if (!ok) return;
      store.importJson(text);
      if (context.mounted) toast(context, 'Backup restored');
    } on FormatException catch (e) {
      if (context.mounted) toast(context, e.message);
    } catch (e) {
      if (context.mounted) toast(context, 'Restore failed: $e');
    }
  }

  Future<void> _currency(BuildContext context) async {
    await showDialog<void>(context: context, builder: (_) => const _CurrencyDialog());
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
        child: Text(text,
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(color: Theme.of(context).colorScheme.primary)),
      );
}

class _CurrencyDialog extends StatefulWidget {
  const _CurrencyDialog();

  @override
  State<_CurrencyDialog> createState() => _CurrencyDialogState();
}

class _CurrencyDialogState extends State<_CurrencyDialog> {
  late final _symbol = TextEditingController(text: store.currency);
  late bool _front = store.symbolFront;

  @override
  void dispose() {
    _symbol.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Currency'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(
          controller: _symbol,
          decoration: const InputDecoration(labelText: 'Symbol', hintText: 'Rs, \$, €, AED…'),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Symbol before amount'),
          value: _front,
          onChanged: (v) => setState(() => _front = v),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            store.setCurrency(_symbol.text, _front);
            Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: ListenableBuilder(
        listenable: store,
        builder: (context, _) => Scaffold(
          appBar: AppBar(
            title: const Text('Categories'),
            bottom: const TabBar(tabs: [Tab(text: 'Expense'), Tab(text: 'Income')]),
          ),
          body: TabBarView(children: [
            _CategoryList(type: TxType.expense),
            _CategoryList(type: TxType.income),
          ]),
        ),
      ),
    );
  }
}

class _CategoryList extends StatelessWidget {
  const _CategoryList({required this.type});
  final TxType type;

  @override
  Widget build(BuildContext context) {
    final cats = store.categoriesOf(type);
    return Scaffold(
      body: ListView(padding: const EdgeInsets.only(bottom: 96), children: [
        for (final c in cats)
          ListTile(
            leading: Text(c.emoji, style: const TextStyle(fontSize: 22)),
            title: Text(c.name),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final ok = await confirm(context, 'Delete ${c.name}?',
                    'Past transactions in this category will show as Uncategorised.');
                if (ok) store.deleteCategory(c.id);
              },
            ),
            onTap: () => _edit(context, c),
          ),
      ]),
      floatingActionButton: FloatingActionButton(
        heroTag: 'add-${type.name}',
        onPressed: () => _edit(context, null),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _edit(BuildContext context, TxCategory? c) async {
    final name = await promptText(context, c == null ? 'New category' : 'Rename category',
        initial: c?.name ?? '', hint: 'Name');
    if (name == null || name.trim().isEmpty || !context.mounted) return;
    final emoji = await promptText(context, 'Emoji (optional)',
        initial: c?.emoji ?? '', hint: 'e.g. ☕');
    final e = (emoji == null || emoji.trim().isEmpty) ? (c?.emoji ?? '📦') : emoji.trim();
    store.upsertCategory(TxCategory(
      id: c?.id ?? newId(),
      name: name.trim(),
      type: type,
      emoji: e,
    ));
  }
}
