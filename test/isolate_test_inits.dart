import 'dart:isolate';

import 'package:isolates/isolates.dart';
import 'package:worker_service/worker_service.dart';

Future globalOuter(Runner runner) async {
  final _runner = runner as IsolateRunner;
  await addLog("global-outer: ${_runner.isolate.debugName}:");
}

Future factoryOuter(Runner runner) async {
  final _runner = runner as IsolateRunner;

  await addLog('factory-outer: ${_runner.isolate.debugName}:');
}

class Data {
  static final logs = <String>[];
}

Future<List<String>> getLogs(String? name) async {
  if (name == null) {
    return Data.logs;
  } else {
    if (!runners.containsKey(name)) {
      throw "Missing runner: $name";
    }
    return await runners[name]!.run(getLogs, null);
  }
}

Future<bool> ping(String name) async {
  if (!runners.containsKey(name)) {
    throw "Missing runner: $name";
  }
  final ping = await runners[name]!.ping();
  return ping;
}

Future addLog(value) async =>
    Data.logs.add("$value ${Isolate.current.debugName}");

final runners = <String, RunnerService>{};

Future testInnerProcess(String debugName, [int poolSize = 3]) async {
  final pool = RunnerFactory.global.create((_) => _
    ..debugName = debugName
    ..poolSize = poolSize
    ..defaultTimeout = Duration(seconds: 2)

    /// Tell the isolate to write a log as soon as it starts
    ..addIsolateInitializerWithParam(addLog, "factory-inner:")
    ..addOnIsolateCreated(factoryOuter)
    ..autoCloseChildren = true);
  await pool.ready();
  runners[debugName] = pool;
}
