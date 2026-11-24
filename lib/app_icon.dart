import 'dart:io';

import 'package:flutter/services.dart';

/// Home-screen icon choices. Keys match the Android activity-alias names.
const kAppIcons = <String, String>{
  'IconTeal': 'teal',
  'IconNavy': 'navy',
  'IconCoral': 'coral',
  'IconGold': 'gold',
};

const _channel = MethodChannel('hisaab/icon');

bool get appIconSupported => Platform.isAndroid;

Future<String> currentAppIcon() async {
  if (!appIconSupported) return 'IconTeal';
  return await _channel.invokeMethod<String>('get') ?? 'IconTeal';
}

Future<void> setAppIcon(String name) async {
  if (!appIconSupported) return;
  await _channel.invokeMethod<void>('set', {'name': name});
}
