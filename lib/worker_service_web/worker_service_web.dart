import 'dart:async';
import 'dart:html';

import 'package:isolate/runner.dart';
import 'package:worker_service/common.dart';

import 'common_web.dart';

class SameIsolateRunner implements Runner {
  @override
  Future<void> close() async {}

  @override
  Future<R> run<R, P>(FutureOr<R> Function(P argument) function, P argument,
      {Duration timeout, FutureOr<R> Function() onTimeout}) {
    return Future.value(function(argument));
  }
}

int workerCounter = 1;

class WebWorkerRunner implements Runner {
  final StreamController _errors = StreamController.broadcast();
  final Worker worker;
  final Map<int, Completer> jobs = {};

  int jobId = 1;
  final int workerNumber;

  WebWorkerRunner()
      : workerNumber = ++workerCounter,
        worker = Worker("worker/web_worker.js") {
    // Listen to Worker's postMessage().
    // dart.html convert the callback to a Stream.
    worker.onMessage.listen((msg) {
      final response = msg.data as RunnerInvocationResult;
      final completer = jobs[response.id];
      if (completer == null) {
        print("Invalid response ${response.id} is missing a completer");
      } else if (response.isSuccess) {
        completer.complete(response.result);
      } else {
        _errors.add(response.error);
        completer.completeError(response.error);
      }
    });
  }

  @override
  Future<void> close() async {
    worker.terminate();
  }

  Stream get errors {
    return _errors.stream;
  }

  @override
  Future<R> run<R, P>(FutureOr<R> Function(P argument) function, P argument,
      {Duration timeout, FutureOr<R> Function() onTimeout}) {
    final _id = ++jobId;
    final invocation = RunnerInvocation(_id, function, argument);
    final completer = Completer<R>();
    jobs[_id] = completer;
    worker.postMessage(invocation);
    return completer.future;
  }
}

String get currentIsolateName {
  return 'webMain';
}

bool get isMainIsolate {
  return true;
}

Future<Runner> spawnRunner(RunnerBuilder builder) async {
  return WebWorkerRunner();
}

Stream<dynamic> getErrorsForRunner(Runner runner) {
  if (runner is WebWorkerRunner) {
    return runner.errors;
  } else {
    return Stream.empty();
  }
}

FutureOr<bool> pingRunner(Runner runner, {Duration timeout}) async {
  final result = await runner.run(_ping, null);
  return result;
}

FutureOr<bool> killRunner(Runner runner, {Duration timeout}) async {
  if (runner is WebWorkerRunner) {
    await runner.close();
    return true;
  }
  return true;
}

bool _ping(_) {
  return true;
}
