import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:isolate/isolate.dart';
import 'package:isolate_service/isolate_service.dart';

void main() {
  group("all", () {
    setUpAll(() {
      RunnerFactory.global.onIsolateCreated((runner) async {
        addLog("global-outer: ${runner.isolate.debugName}:");
      });

      RunnerFactory.global.addIsolateInitializer(addLog, "global-inner:");
    });

    setUp(() {
      logs.clear();
      childIsolates.clear();
    });

    test("Killing parent isolate autocloses all children", () async {
      final parent = await RunnerFactory.global.spawn((_) => _
        ..spawnCount = 0
        ..debugName = "parentIsolate");

      // Verify parent logs
      final parentLogs = await parent.execute(getLogs);
      expect(parentLogs, equals(['global-inner: parentIsolate']));
      expect(logs, equals(['global-outer: parentIsolate: main']));
      final result = await parent.run(_testInnerProcess, null);

      // Check logs
      final resultLogs = await result.execute(getLogs);
      expect(resultLogs, equals(['factory-inner: runnerMan']));
      expect(
          await parent.execute(getLogs),
          equals([
            'global-inner: parentIsolate',
            'factory-outer: runnerMan: parentIsolate'
          ]));
      expect(logs, equals(['global-outer: parentIsolate: main']));
      final ping = await result.ping();
      expect(ping, equals(true));

      /// Kill the parent.
      await parent.kill(timeout: Duration.zero);
      await Future.delayed(Duration(milliseconds: 100));
      final parentPing2 = await parent.ping();
      expect(parentPing2, equals(false),
          reason:
              "After killing the parent isolate, a ping to the parent should fail");
      final ping2 = await result.ping();
      expect(ping2, equals(false),
          reason: "After killing the parent, the child should also be removed");
    });

    test("Initializers run", () async {
      final isolate = await _testInnerProcess(null);
      final ping = await isolate.ping();
      expect(ping, equals(true));
      final isolateLogs = await isolate.run(getLogs, null);
      expect(isolateLogs,
          equals(['global-inner: runnerMan', 'factory-inner: runnerMan']));
      expect(
          logs,
          equals([
            'global-outer: runnerMan: main',
            'factory-outer: runnerMan: main'
          ]));
    });
  });
}

final childIsolates = <Isolate>[];
List<Isolate> getChildIsolates(_) => childIsolates;

final logs = <String>[];
List<String> getLogs(_) => logs;
Future addLog(value) async => logs.add("$value ${Isolate.current.debugName}");

Future<IsolateRunner> _testInnerProcess(_) async {
  final pool = await RunnerFactory.global.spawn((_) => _
    ..debugName = "runnerMan"
    ..spawnCount = 3
    ..addIsolateInitializer(addLog, "factory-inner:")
    ..onIsolateCreated((runner) async {
      addLog("factory-outer: ${runner.isolate.debugName}:");
    })
    ..autoclose = true);

  return pool;
}
