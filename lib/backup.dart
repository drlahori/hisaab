import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import 'store.dart';

/// Frequencies offered in Settings (days -> label). 0 means off.
const kBackupFrequencies = <int, String>{
  0: 'Off',
  1: 'Daily',
  7: 'Weekly',
  15: 'Every 15 days',
  30: 'Every 30 days',
};

const _keep = 10; // newest backups kept in the folder

String backupFolderLabel() => Platform.isAndroid
    ? 'Phone storage → Download → Hisaab'
    : 'Files app → On My iPhone → Hisaab → Backups';

Future<List<Directory>> _candidates() async {
  final dirs = <Directory>[];
  if (Platform.isAndroid) {
    // Shared Download folder: survives uninstalling the app.
    dirs.add(Directory('/storage/emulated/0/Download/Hisaab'));
    final ext = await getExternalStorageDirectory();
    if (ext != null) dirs.add(Directory('${ext.path}/Backups'));
  }
  final docs = await getApplicationDocumentsDirectory();
  dirs.add(Directory('${docs.path}/Backups'));
  return dirs;
}

/// Writes a backup file to phone storage and returns it.
Future<File> writeBackupToPhone() async {
  final name = 'hisaab-backup-${DateFormat('yyyy-MM-dd_HHmmss').format(DateTime.now())}.json';
  final content = store.exportJson();
  Object? lastError;
  for (final dir in await _candidates()) {
    try {
      await dir.create(recursive: true);
      final file = File('${dir.path}/$name');
      await file.writeAsString(content, flush: true);
      await _prune(dir);
      store.markBackedUp(DateTime.now(), file.path);
      return file;
    } catch (e) {
      lastError = e;
    }
  }
  throw Exception('Could not save a backup: $lastError');
}

Future<void> _prune(Directory dir) async {
  try {
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) {
          final n = f.uri.pathSegments.last;
          return n.startsWith('hisaab-backup-') && n.endsWith('.json');
        })
        .toList()
      ..sort((a, b) => b.path.compareTo(a.path));
    for (final f in files.skip(_keep)) {
      await f.delete();
    }
  } catch (_) {
    // Old files we can't delete are harmless.
  }
}

bool _running = false;

/// Called when the app opens or comes back to the front.
Future<void> maybeAutoBackup() async {
  final days = store.autoBackupDays;
  if (days <= 0 || _running) return;
  final last = store.lastAutoBackup;
  final due = last == null || DateTime.now().difference(last).inHours >= days * 24 - 2;
  if (!due) return;
  _running = true;
  try {
    await writeBackupToPhone();
  } catch (e) {
    debugPrint('Auto backup failed: $e');
  } finally {
    _running = false;
  }
}
