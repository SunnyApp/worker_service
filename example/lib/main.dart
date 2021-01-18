import 'dart:html';

import 'package:dorker/dorker.dart';
import 'package:flutter/cupertino.dart';
import 'package:worker_service_example/test_work_proxies.dart';
import 'package:worker_service/ports.dart';

// import 'long_task_platform.dart' if (dart.library.js) 'long_task.dart';

Future main() async {
  Dorker _concatDorker;
  Dorker _concatSharedDorker;
  if (const String.fromEnvironment('USE_WORKER') != 'true') {
    print('Asked to use worker');
    _concatDorker = DorkerWorker(Worker('/long_task_web.dart.js'));
    _concatDorker.onMessage.forEach((element) {
      print("Got message from worker: $element");
    });
    // _concatSharedDorker = DorkerSharedWorker(
    //     SharedWorker('worker/concater_sharedworker.dart.js'));
  } else {
    print(
        'Not using worker. Share worker across multiple Tab will not work as intended');
    _concatDorker = Dorker();
    _concatSharedDorker = Dorker();
    // Concater(Dorker.CrossLink(_concatSharedDorker));
  }

  _concatDorker.postMessage.add("Hey!!!");

  // var _dorker = DorkerWorker(
  //     Worker('packages/worker_service_example/long_task.dart.lib.js'));
  // _dorker.onMessage.listen((data_from_worker) => print(data_from_worker));
  // _dorker.postMessage.add('Start working!');

  // if (true == false) {
  //   initializeLongTask();
  // }
  // var e = IsolateEntry(
  //     entryFunction: doStuff,
  //     entryFileName: "packages/worker_service_example/long_task.dart.lib.js");
  // var proxy = await spawnWorkProxy(e, "Bob");
  // proxy.sendToIsolate("Hello");
  runApp(TestWorkProxies(dorker: _concatDorker));
}
