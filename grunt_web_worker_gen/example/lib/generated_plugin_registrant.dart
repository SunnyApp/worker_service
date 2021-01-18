//
// Generated file. Do not edit.
//

// ignore: unused_import
import 'dart:ui';

import 'package:file_picker/src/file_picker_web.dart';
import 'package:firebase_auth_web/firebase_auth_web.dart';
import 'package:firebase_core_web/firebase_core_web.dart';
import 'package:firebase_storage_web/firebase_storage_web.dart';
import 'package:flutter_keyboard_visibility_web/flutter_keyboard_visibility_web.dart';
import 'package:import_js_library/import_js_library.dart';
import 'package:url_launcher_web/url_launcher_web.dart';
import 'package:video_player_web/video_player_web.dart';
import 'package:wakelock_web/wakelock_web.dart';

import 'package:flutter_web_plugins/flutter_web_plugins.dart';

// ignore: public_member_api_docs
void registerPlugins(PluginRegistry registry) {
  FilePickerWeb.registerWith(registry.registrarFor(FilePickerWeb));
  FirebaseAuthWeb.registerWith(registry.registrarFor(FirebaseAuthWeb));
  FirebaseCoreWeb.registerWith(registry.registrarFor(FirebaseCoreWeb));
  FirebaseStorageWeb.registerWith(registry.registrarFor(FirebaseStorageWeb));
  FlutterKeyboardVisibilityPlugin.registerWith(registry.registrarFor(FlutterKeyboardVisibilityPlugin));
  ImportJsLibrary.registerWith(registry.registrarFor(ImportJsLibrary));
  UrlLauncherPlugin.registerWith(registry.registrarFor(UrlLauncherPlugin));
  VideoPlayerPlugin.registerWith(registry.registrarFor(VideoPlayerPlugin));
  WakelockWeb.registerWith(registry.registrarFor(WakelockWeb));
  registry.registerMessageHandler();
}
