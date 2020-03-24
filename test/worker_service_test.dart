import 'package:flutter_test/flutter_test.dart';
import 'package:sunny_dart/sunny_dart.dart';
import 'package:worker_service/worker_service.dart';

import 'isolate_test_inits.dart';

void main() {
  group("all", () {
    setUpAll(() {
      WorkhorseFactory.global.onIsolateCreated(globalOuter);
      WorkhorseFactory.global.addIsolateInitializer(addLog, "global-inner:");
    });

    setUp(() {
      Data.logs.clear();
    });

    test("Killing parent isolate autocloses all children", () async {
      final parent = await WorkhorseFactory.global
          .create((_) => _
            ..debugName = 'parentIsolate'
            ..poolSize = 1
            ..failOnError = true
            ..defaultTimeout = Duration(seconds: 60)
            ..autoclose = true)
          .ready();

      parent.errors.forEach((error) {
        print('##############################################################');
        print("$error");
        print('##############################################################');
      }).ignore();

      // Verify parent logs
      final parentLogs = await parent.run(getLogs, null);
      expect(parentLogs, equals(['global-inner: parentIsolate']));
      expect(Data.logs, equals(['global-outer: parentIsolate: main']));

      const runnerMan = "runnerMan";
      await parent.run(testInnerProcess, runnerMan);

      // Check logs
      final resultLogs = await parent.run(getLogs, runnerMan);
      expect(resultLogs, equals(['factory-inner: $runnerMan: 1']));
      expect(
          await parent.run(getLogs, null),
          containsAll([
            'global-inner: parentIsolate',
            'factory-outer: $runnerMan: 1: parentIsolate',
            'factory-outer: $runnerMan: 2: parentIsolate',
            'factory-outer: $runnerMan: 3: parentIsolate',
          ]));
//      expect(Data.logs, equals(['global-outer: parentIsolate: main']));
      final pingResult = await parent.run(ping, runnerMan);
      expect(pingResult, equals(true));

      /// Kill the parent.
      await parent.close();
      await Future.delayed(Duration(milliseconds: 100));
      final parentPing2 = await parent.ping();
      expect(parentPing2, equals(false), reason: "After killing the parent isolate, a ping to the parent should fail");
    });

    test("Initializers run", () async {
      const initializer = "initializerTest";
      await testInnerProcess(initializer);
      final pingResult = await ping(initializer);
      expect(pingResult, equals(true));
      final isolateLogs = await getLogs(initializer);
      expect(
          isolateLogs,
          containsAll([
            'global-inner: $initializer: 1',
            'factory-inner: $initializer: 1',
          ]));
      expect(
          Data.logs,
          containsAll([
            'global-outer: $initializer: 1: main',
            'factory-outer: $initializer: 1: main',
          ]));
    });
  });
}
