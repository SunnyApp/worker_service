import 'dart:async';
import 'dart:html';

import 'package:isolate/runner.dart';
import 'package:worker_service/common.dart';

import 'common_web.dart';

export 'web_worker.dart';

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

class WebWorkerRunner<P, R> implements Workhorse<P, R> {
  final StreamController _errors = StreamController.broadcast();

  final String workerScript;
  final Map<int, Completer> jobs = {};
  ServiceWorkerRegistration worker;
  int jobId = 1;
  final int workerNumber;

  WebWorkerRunner._(this.workerScript, this.worker) : workerNumber = ++workerCounter {
    worker.addEventListener("any", (Event event) {
      print("Got message: $event");
      if (event is MessageEvent) {
        final response = event.data as RunnerInvocationResult;
        final completer = jobs[response.id];
        if (completer == null) {
          print("Invalid response ${response.id} is missing a completer");
        } else if (response.isSuccess) {
          completer.complete(response.result);
        } else {
          _errors.add(response.error);
          completer.completeError(response.error);
        }
      }

      worker.dispatchEvent(MessageEvent("result", canBubble: true, data: {"response": 42}));
    }, true);
  }

  static Future<WebWorkerRunner<P, R>> of<P, R>([String workerScript]) async {
    workerScript ??= "web_worker.dart.lib.js";
    final registration = await window.navigator.serviceWorker.register(workerScript);
    return WebWorkerRunner<P, R>._(workerScript, registration);
  }

  @override
  Future<void> close() async {
    await worker.unregister();
    print("SW stopped");
  }

  Stream get errors {
    return _errors.stream;
  }

  @override
  FutureOr<R> run(function, P argument, {Duration timeout, FutureOr<R> Function() onTimeout}) {
    final _id = ++jobId;
    final invocation = RunnerInvocation(_id, function, argument);
    final completer = Completer<R>();
    jobs[_id] = completer;
    final result = worker.dispatchEvent(MessageEvent("invoke", data: invocation));
    return completer.future;
  }
}

String get currentIsolateName {
  return 'webMain';
}

bool get isMainIsolate {
  return true;
}

Future<Workhorse> spawnRunner(RunnerBuilder builder) async {
  return await WebWorkerRunner.of();
}

Stream<dynamic> getErrorsForRunner(Workhorse runner) {
  if (runner is WebWorkerRunner) {
    return runner.errors;
  } else {
    return Stream.empty();
  }
}

FutureOr<bool> pingRunner(Workhorse runner, {Duration timeout}) async {
  final result = await runner.run(_ping, null);
  return result as bool;
}

FutureOr<bool> killRunner(Workhorse runner, {Duration timeout}) async {
  if (runner is WebWorkerRunner) {
    await runner.close();
    return true;
  }
  return true;
}

bool _ping(_) {
  return true;
}
