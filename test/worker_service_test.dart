import 'package:flutter_test/flutter_test.dart';
import 'package:sunny_dart/sunny_dart.dart';
import 'package:worker_service/worker_service.dart';

import 'isolate_test_inits.dart';

void main() {
  group("all", () {
    setUpAll(() {});

    setUp(() {
      RunnerFactory.global.reset();
      RunnerFactory.global.onIsolateCreated(globalOuter);
      RunnerFactory.global.addIsolateInitializerParam(addLog, "global-inner:");
      Data.logs.clear();
    });

    test("Initializers run", () async {
      const initializer = "initializerTest";

      /// We only want to create a single item in the pool
      await testInnerProcess(initializer, 1);
      final pingResult = await ping(initializer);
      expect(pingResult, equals(true));
      final isolateLogs = await getLogs(initializer);
      expect(
          isolateLogs,
          containsAll([
            'global-inner: $initializer',
            'factory-inner: $initializer',
          ]));
      expect(
          Data.logs,
          containsAll([
            'global-outer: $initializer: main',
            'factory-outer: $initializer: main',
          ]));
    });

    test("Killing parent isolate autocloses all children", () async {
      final parent = await RunnerFactory.global
          .create((_) => _
            ..debugName = 'parentIsolate'
            ..poolSize = 1
            ..failOnError = true
            ..defaultTimeout = Duration(seconds: 60)
            ..autoCloseChildren = true)
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
      expect(
          resultLogs,
          containsAny([
            'factory-inner: $runnerMan: 1',
            'factory-inner: $runnerMan: 2',
            'factory-inner: $runnerMan: 3'
          ]));
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
      expect(parentPing2, equals(false),
          reason:
              "After killing the parent isolate, a ping to the parent should fail");
    });
  });
}

containsAny(List any) => _ContainsAny(any);

class _ContainsAny extends Matcher {
  final List _expected;

  const _ContainsAny(this._expected);

  @override
  bool matches(item, Map matchState) {
    if (item is Iterable) {
      return item.any((actual) => _expected.any((expect) => expect == actual));
    } else {
      return false;
    }
  }

  @override
  Description describe(Description description) =>
      description.add('contains any ').addDescriptionOf(_expected);

  @override
  Description describeMismatch(
      item, Description mismatchDescription, Map matchState, bool verbose) {
    if (item is Iterable) {
      return super
          .describeMismatch(item, mismatchDescription, matchState, verbose);
    } else {
      return mismatchDescription.add('is not a string, map or iterable');
    }
  }
}
