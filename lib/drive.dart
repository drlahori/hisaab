import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:path_provider/path_provider.dart';

/// Web OAuth client ID from Google Cloud, passed in at build time:
/// flutter build apk --dart-define=GOOGLE_WEB_CLIENT_ID=xxxx.apps.googleusercontent.com
const kWebClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');

bool get driveConfigured => kWebClientId.isNotEmpty;

const _scopes = ['https://www.googleapis.com/auth/drive.file'];
const _folderName = 'Hisaab Backups';
const _keepOnDrive = 30;

class DriveResult {
  DriveResult(this.id, this.name, this.created);
  final String id;
  final String name;
  final DateTime created;
}

/// Backs up to the user's own Google Drive, into a "Hisaab Backups" folder.
/// Uses the drive.file scope: the app only sees files it created itself.
class DriveSync extends ChangeNotifier {
  String? email;
  String? _folderId;
  DateTime? lastBackup;
  String? lastError;
  bool busy = false;

  bool _initDone = false;
  GoogleSignInAccount? _account;

  bool get connected => email != null;

  Future<File> _file() async =>
      File('${(await getApplicationDocumentsDirectory()).path}/hisaab_drive.json');

  Future<void> load() async {
    try {
      final f = await _file();
      if (await f.exists()) {
        final j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
        email = j['email'] as String?;
        _folderId = j['folderId'] as String?;
        lastBackup = DateTime.tryParse((j['lastBackup'] as String?) ?? '');
        lastError = j['lastError'] as String?;
      }
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      final f = await _file();
      await f.writeAsString(jsonEncode({
        'email': email,
        'folderId': _folderId,
        'lastBackup': lastBackup?.toIso8601String(),
        'lastError': lastError,
      }));
    } catch (_) {}
  }

  Future<void> _init() async {
    if (_initDone || !driveConfigured) return;
    _initDone = true;
    await GoogleSignIn.instance.initialize(serverClientId: kWebClientId);
  }

  /// Interactive: pick a Google account and allow Drive access.
  Future<void> connect() async {
    if (!driveConfigured) throw Exception('Google Drive is not set up in this build.');
    await _init();
    final acct = await GoogleSignIn.instance.authenticate(scopeHint: _scopes);
    await acct.authorizationClient.authorizeScopes(_scopes);
    _account = acct;
    email = acct.email;
    _folderId = null;
    lastError = null;
    await _save();
    notifyListeners();
  }

  Future<void> disconnect() async {
    try {
      await _init();
      await GoogleSignIn.instance.disconnect();
    } catch (_) {}
    _account = null;
    email = null;
    _folderId = null;
    lastBackup = null;
    lastError = null;
    await _save();
    notifyListeners();
  }

  Future<Map<String, String>> _headers({required bool interactive}) async {
    await _init();
    _account ??= await GoogleSignIn.instance.attemptLightweightAuthentication();
    if (_account == null && interactive) {
      _account = await GoogleSignIn.instance.authenticate(scopeHint: _scopes);
    }
    final client = _account?.authorizationClient ?? GoogleSignIn.instance.authorizationClient;
    final h = await client.authorizationHeaders(_scopes, promptIfNecessary: interactive);
    if (h == null) throw Exception('Google Drive needs you to sign in again. Tap Reconnect.');
    return h;
  }

  Future<(int, String)> _send(
    String method,
    Uri url,
    Map<String, String> headers, {
    List<int>? body,
    String? contentType,
  }) async {
    final client = HttpClient();
    try {
      final req = await client.openUrl(method, url);
      headers.forEach(req.headers.set);
      if (contentType != null) req.headers.set(HttpHeaders.contentTypeHeader, contentType);
      if (body != null) {
        req.contentLength = body.length;
        req.add(body);
      }
      final res = await req.close();
      final text = await res.transform(utf8.decoder).join();
      return (res.statusCode, text);
    } finally {
      client.close();
    }
  }

  /// Runs [call] with auth headers; on 401 clears the token and retries once.
  Future<(int, String)> _authed(
      Future<(int, String)> Function(Map<String, String> h) call, bool interactive) async {
    var h = await _headers(interactive: interactive);
    var r = await call(h);
    if (r.$1 == 401) {
      final token = (h['Authorization'] ?? '').replaceFirst('Bearer ', '');
      final client = _account?.authorizationClient ?? GoogleSignIn.instance.authorizationClient;
      await client.clearAuthorizationToken(accessToken: token);
      h = await _headers(interactive: interactive);
      r = await call(h);
    }
    if (r.$1 >= 400) throw Exception('Google Drive error ${r.$1}: ${_short(r.$2)}');
    return r;
  }

  String _short(String s) => s.length > 200 ? '${s.substring(0, 200)}…' : s;

  static final _api = Uri.parse('https://www.googleapis.com/drive/v3/files');

  Future<String> _folder(bool interactive) async {
    final cached = _folderId;
    if (cached != null) return cached;
    final q = "name='$_folderName' and mimeType='application/vnd.google-apps.folder' and trashed=false";
    final found = await _authed(
      (h) => _send('GET', _api.replace(queryParameters: {'q': q, 'fields': 'files(id)', 'spaces': 'drive'}), h),
      interactive,
    );
    final files = (jsonDecode(found.$2)['files'] as List?) ?? const [];
    if (files.isNotEmpty) {
      _folderId = (files.first as Map)['id'] as String;
    } else {
      final made = await _authed(
        (h) => _send('POST', _api.replace(queryParameters: {'fields': 'id'}), h,
            body: utf8.encode(jsonEncode({
              'name': _folderName,
              'mimeType': 'application/vnd.google-apps.folder',
            })),
            contentType: 'application/json; charset=UTF-8'),
        interactive,
      );
      _folderId = jsonDecode(made.$2)['id'] as String;
    }
    await _save();
    return _folderId!;
  }

  /// Uploads one backup file. Set [interactive] when the user tapped a button.
  Future<void> upload(String name, String content, {bool interactive = false}) async {
    if (!connected) return;
    busy = true;
    notifyListeners();
    try {
      final folder = await _folder(interactive);
      const boundary = 'hisaab_backup_boundary';
      final body = utf8.encode('--$boundary\r\n'
          'Content-Type: application/json; charset=UTF-8\r\n\r\n'
          '${jsonEncode({'name': name, 'parents': [folder]})}\r\n'
          '--$boundary\r\n'
          'Content-Type: application/json\r\n\r\n'
          '$content\r\n'
          '--$boundary--\r\n');
      final up = Uri.parse(
          'https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart&fields=id');
      try {
        await _authed(
          (h) => _send('POST', up, h,
              body: body, contentType: 'multipart/related; boundary=$boundary'),
          interactive,
        );
      } on Exception catch (e) {
        // The folder may have been deleted from Drive; find or make it again once.
        if (!e.toString().contains('404')) rethrow;
        _folderId = null;
        final f2 = await _folder(interactive);
        final body2 = utf8.encode(utf8.decode(body).replaceFirst(folder, f2));
        await _authed(
          (h) => _send('POST', up, h,
              body: body2, contentType: 'multipart/related; boundary=$boundary'),
          interactive,
        );
      }
      lastBackup = DateTime.now();
      lastError = null;
      await _prune(interactive);
    } catch (e) {
      lastError = e.toString().replaceFirst('Exception: ', '');
      rethrow;
    } finally {
      busy = false;
      await _save();
      notifyListeners();
    }
  }

  Future<List<DriveResult>> listBackups({bool interactive = true}) async {
    final folder = await _folder(interactive);
    final r = await _authed(
      (h) => _send(
          'GET',
          _api.replace(queryParameters: {
            'q': "'$folder' in parents and trashed=false",
            'orderBy': 'createdTime desc',
            'fields': 'files(id,name,createdTime)',
            'pageSize': '100',
            'spaces': 'drive',
          }),
          h),
      interactive,
    );
    final files = (jsonDecode(r.$2)['files'] as List?) ?? const [];
    return [
      for (final f in files.cast<Map>())
        DriveResult(f['id'] as String, (f['name'] as String?) ?? '',
            DateTime.tryParse((f['createdTime'] as String?) ?? '')?.toLocal() ?? DateTime.now()),
    ];
  }

  Future<String> download(String id) async {
    final r = await _authed(
      (h) => _send('GET', _api.replace(path: '${_api.path}/$id', queryParameters: {'alt': 'media'}), h),
      true,
    );
    return r.$2;
  }

  Future<void> _prune(bool interactive) async {
    try {
      final all = await listBackups(interactive: interactive);
      for (final f in all.skip(_keepOnDrive)) {
        await _authed(
          (h) => _send('DELETE', _api.replace(path: '${_api.path}/${f.id}'), h),
          interactive,
        );
      }
    } catch (e) {
      debugPrint('Drive prune failed: $e');
    }
  }
}

final drive = DriveSync();
