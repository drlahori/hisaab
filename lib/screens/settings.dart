import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../app_icon.dart';
import '../backup.dart';
import '../common.dart';
import '../lock.dart';
import '../models.dart';
import '../store.dart';
import 'budgets.dart';
import 'calculator.dart';
import 'lock_screens.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('More'), centerTitle: true),
        body: ListView(children: [
          const _Header('Automatic backup'),
          ListTile(
            leading: const Icon(Icons.schedule),
            title: const Text('Auto backup'),
            subtitle: Text(kBackupFrequencies[store.autoBackupDays] ?? 'Off'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _pickFrequency(context),
          ),
          ListTile(
            leading: const Icon(Icons.folder_outlined),
            title: const Text('Saved to'),
            subtitle: Text(backupFolderLabel()),
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('Last backup'),
            subtitle: Text(store.lastAutoBackup == null
                ? 'Never'
                : DateFormat('EEE, d MMM yyyy · h:mm a').format(store.lastAutoBackup!)),
            trailing: TextButton(
              onPressed: () => _backupToPhone(context),
              child: const Text('Back up now'),
            ),
          ),
          const ListTile(
            leading: Icon(Icons.add_to_drive_outlined),
            title: Text('Google Drive'),
            subtitle: Text('Coming in the next update'),
            enabled: false,
          ),
          const _Header('Share & restore'),
          Builder(
            builder: (ctx) => ListTile(
              leading: const Icon(Icons.ios_share),
              title: const Text('Share a backup'),
              subtitle: const Text('Send to Google Drive, Gmail, WhatsApp, Files…'),
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
          ListenableBuilder(
            listenable: appLock,
            builder: (context, _) => ListTile(
              leading: const Icon(Icons.lock_outline),
              title: const Text('App lock'),
              subtitle: Text(const {'pin': 'PIN', 'pattern': 'Pattern'}[appLock.type] ?? 'Off'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const AppLockScreen()),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dark_mode_outlined),
            title: const Text('Theme'),
            subtitle: Text(const {'system': 'Same as phone', 'light': 'Light', 'dark': 'Dark'}[store.theme] ?? 'Same as phone'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _pickTheme(context),
          ),
          ListTile(
            leading: const Icon(Icons.calculate_outlined),
            title: const Text('Calculator'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => openCalculator(context),
          ),
          if (appIconSupported)
            ListTile(
              leading: const Icon(Icons.apps),
              title: const Text('App icon'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const AppIconScreen()),
              ),
            ),
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
            title: Text('Hisaab 1.3'),
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
      final f = await FilePicker.pickFile(type: FileType.any);
      if (f == null) return;
      final bytes = await f.readAsBytes();
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

  Future<void> _pickTheme(BuildContext context) async {
    const options = {'system': 'Same as phone', 'light': 'Light', 'dark': 'Dark'};
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Theme'),
        children: [
          for (final e in options.entries)
            ListTile(
              title: Text(e.value),
              trailing: store.theme == e.key ? const Icon(Icons.check) : null,
              onTap: () => Navigator.pop(ctx, e.key),
            ),
        ],
      ),
    );
    if (picked != null) store.setTheme(picked);
  }

  Future<void> _pickFrequency(BuildContext context) async {
    final picked = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Auto backup'),
        children: [
          for (final e in kBackupFrequencies.entries)
            ListTile(
              title: Text(e.value),
              trailing: store.autoBackupDays == e.key ? const Icon(Icons.check) : null,
              onTap: () => Navigator.pop(ctx, e.key),
            ),
        ],
      ),
    );
    if (picked == null) return;
    store.setAutoBackup(picked);
    if (picked > 0) await _backupToPhone(context);
  }

  Future<void> _backupToPhone(BuildContext context) async {
    try {
      await writeBackupToPhone();
      if (context.mounted) toast(context, 'Backup saved to ${backupFolderLabel()}');
    } catch (e) {
      if (context.mounted) toast(context, 'Backup failed: $e');
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

class AppIconScreen extends StatefulWidget {
  const AppIconScreen({super.key});

  @override
  State<AppIconScreen> createState() => _AppIconScreenState();
}

class _AppIconScreenState extends State<AppIconScreen> {
  String? _current;

  @override
  void initState() {
    super.initState();
    currentAppIcon().then((v) {
      if (mounted) setState(() => _current = v);
    }).catchError((Object _) {
      if (mounted) setState(() => _current = 'IconTeal');
    });
  }

  Future<void> _choose(String name) async {
    try {
      await setAppIcon(name);
      setState(() => _current = name);
      if (mounted) {
        toast(context, 'Icon changed. Your home screen may take a few seconds to update.');
      }
    } catch (e) {
      if (mounted) toast(context, 'Could not change the icon: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('App icon')),
      body: _current == null
          ? const Center(child: CircularProgressIndicator())
          : GridView.count(
              crossAxisCount: 2,
              padding: const EdgeInsets.all(24),
              mainAxisSpacing: 24,
              crossAxisSpacing: 24,
              children: [
                for (final e in kAppIcons.entries)
                  InkWell(
                    borderRadius: BorderRadius.circular(28),
                    onTap: () => _choose(e.key),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: _current == e.key ? scheme.primary : scheme.outlineVariant,
                          width: _current == e.key ? 3 : 1,
                        ),
                      ),
                      child: Column(children: [
                        Expanded(child: Image.asset('assets/icons/${e.value}.png')),
                        const SizedBox(height: 8),
                        Text(
                          e.value[0].toUpperCase() + e.value.substring(1),
                          style: TextStyle(
                            fontWeight: _current == e.key ? FontWeight.w700 : FontWeight.w400,
                          ),
                        ),
                      ]),
                    ),
                  ),
              ],
            ),
    );
  }
}
