import 'dart:html' as web;

import 'package:worker_service/work/grunt_channel.dart';
import 'package:meta/meta.dart';
import 'package:worker_service/work/grunt_registry.dart';
import 'package:worker_service/work/platform/grunt_platform_webworker.dart';
// import 'package:flutter/foundation.dart' show kDebugMode;


Future<DuplexChannel> createGruntChannel(GruntFactory fn,
    {required bool isProduction}) async {

  var fullPath = "";
  final package = fn.package;
  final path = fn.key;
  if (isProduction == true) {
    fullPath = "/assets";
    if (fn.package != null) {
      fullPath += "/packages/${fn.package}";
    }
    fullPath += "/lib/${fn.key}.grunt.dart.js";
  } else {
    var childUrl = "";
    if (package != null) {
      childUrl += "/packages/$package";
    }
    childUrl += "/$path.grunt.dart.lib.js";
    fullPath =
        "/assets/packages/worker_service/lib/bootstrap_dev.js?grl=${Uri.encodeFull(childUrl)}";
  }
  var ww = web.Worker(fullPath);
  return WebDuplexChannel(ww, fn.encoding, debugLabel: 'main app');
}

DuplexChannel connectToSupervisor(GruntFactory factory) {
  return WWDuplexChannel(factory.encoding);
}
