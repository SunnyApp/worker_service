import 'dart:html';

import 'package:js/js.dart';

@pragma('vm:entry-point')
void main() {
  window.addEventListener('install', allowInterop((event) {
    print("Installed");
  }));
}
