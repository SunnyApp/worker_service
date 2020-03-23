import 'dart:async';

import 'package:isolate/runner.dart';
import 'package:worker_service/common.dart';

Stream<dynamic> getErrorsForRunner(Runner runner) =>
    throw 'Not implemented for platform';

FutureOr<bool> pingRunner(Runner runner, {Duration timeout}) async =>
    throw 'Not implemented for platform';

FutureOr<bool> killRunner(Runner runner, {Duration timeout}) async =>
    throw 'Not implemented for platform';

String get currentIsolateName => null;

bool get isMainIsolate => null;

/// Spawns a new isolate with any extra processing.  It's required to have a top-level spawner method
Future<Runner> spawnRunner(RunnerBuilder factory) async =>
    throw 'Not implemented for platform';
