import 'dart:async';

import 'package:isolate/runner.dart';
import 'package:isolate_service/common.dart';

class SameIsolateRunner implements Runner {
  @override
  Future<void> close() async {}

  @override
  Future<R> run<R, P>(FutureOr<R> Function(P argument) function, P argument,
      {Duration timeout, FutureOr<R> Function() onTimeout}) {
    return Future.value(function(argument));
  }
}

String get currentIsolateName {
  return 'webMain';
}

bool get isMainIsolate {
  return true;
}

Future<Runner> spawnRunner(RunnerBuilder builder) async {
  return SameIsolateRunner();
}

Stream<dynamic> getErrorsForRunner(Runner runner) {
  return Stream.empty();
}

FutureOr<bool> pingRunner(Runner runner, {Duration timeout}) async {
  return true;
}

FutureOr<bool> killRunner(Runner runner, {Duration timeout}) async {
  return true;
}
