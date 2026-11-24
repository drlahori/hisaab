import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// App lock settings live in their own file, so backups never contain them
/// and restoring a backup never changes the lock.
class AppLock extends ChangeNotifier {
  String type = 'off'; // off | pin | pattern
  String? _hash;
  String _salt = '';
  bool locked = false;
  DateTime? _pausedAt;
  int _failures = 0;
  DateTime? blockedUntil;

  static const awayLimit = Duration(seconds: 30);

  bool get enabled => type != 'off' && _hash != null;

  Future<File> _file() async =>
      File('${(await getApplicationDocumentsDirectory()).path}/hisaab_lock.json');

  Future<void> load() async {
    try {
      final f = await _file();
      if (await f.exists()) {
        final j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
        type = (j['type'] as String?) ?? 'off';
        _hash = j['hash'] as String?;
        _salt = (j['salt'] as String?) ?? '';
      }
    } catch (_) {}
    locked = enabled;
  }

  Future<void> _save() async {
    final f = await _file();
    await f.writeAsString(jsonEncode({'type': type, 'hash': _hash, 'salt': _salt}), flush: true);
  }

  String _digest(String secret) => sha256.convert(utf8.encode('$_salt:$secret')).toString();

  /// Returns true if [secret] is right. Wrong answers 5 times in a row block for 30 seconds.
  bool check(String secret) {
    if (!enabled) return true;
    if (blockedUntil != null && DateTime.now().isBefore(blockedUntil!)) return false;
    if (_digest(secret) == _hash) {
      _failures = 0;
      blockedUntil = null;
      return true;
    }
    _failures++;
    if (_failures >= 5) {
      _failures = 0;
      blockedUntil = DateTime.now().add(const Duration(seconds: 30));
    }
    return false;
  }

  Future<void> set(String newType, String secret) async {
    final r = Random.secure();
    _salt = List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    type = newType;
    _hash = _digest(secret);
    await _save();
    notifyListeners();
  }

  Future<void> disable() async {
    type = 'off';
    _hash = null;
    _salt = '';
    locked = false;
    await _save();
    notifyListeners();
  }

  void unlock() {
    locked = false;
    notifyListeners();
  }

  void onPaused() => _pausedAt ??= DateTime.now();

  void onResumed() {
    final at = _pausedAt;
    _pausedAt = null;
    if (enabled && at != null && DateTime.now().difference(at) >= awayLimit) {
      locked = true;
      notifyListeners();
    }
  }
}

final appLock = AppLock();

/// Patterns are stored as dot numbers 1-9, e.g. "1-5-9-6".
String patternKey(List<int> dots) => dots.map((d) => d + 1).join('-');
