import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:isolate/isolate_runner.dart';
import 'package:isolate_service/isolate_service.dart';

globalOuter(IsolateRunner runner) async {
  await addLog("global-outer: ${runner.isolate.debugName}:");
}

factoryOuter(IsolateRunner runner) async {
  await addLog("factory-outer: ${runner.isolate.debugName}:");
}

class Data {
  static final logs = <String>[];
}

Future<List<String>> getLogs(String name) async {
  if (name == null) {
    return Data.logs;
  } else {
    if (!runners.containsKey(name)) {
      throw "Missing runner: $name";
    }
    return await runners[name].run(getLogs, null);
  }
}

Future<bool> ping(String name) async {
  if (!runners.containsKey(name)) {
    throw "Missing runner: $name";
  }
  final ping = await runners[name].ping();
  return ping;
}

Future addLog(value) async => Data.logs.add("$value ${Isolate.current.debugName}");

final runners = <String, IsolateService>{};

testInnerProcess(String debugName) async {
  final pool = RunnerFactory.global.create((_) => _
    ..debugName = debugName
    ..poolSize = 3
    ..defaultTimeout = Duration(seconds: 2)
    ..addIsolateInitializer(addLog, "factory-inner:")
    ..onIsolateCreated(factoryOuter)
    ..autoclose = true);
  await pool.ready();
  runners[debugName] = pool;
}
