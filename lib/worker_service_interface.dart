import 'dart:async';

import 'package:worker_service/common.dart';

Stream<dynamic> getErrorsForRunner(Workhorse runner) => throw 'Not implemented for platform';

FutureOr<bool> pingRunner(Workhorse runner, {Duration timeout}) async => throw 'Not implemented for platform';

FutureOr<bool> killRunner(Workhorse runner, {Duration timeout}) async => throw 'Not implemented for platform';

String get currentIsolateName => null;

bool get isMainIsolate => null;

/// Spawns a new isolate with any extra processing.  It's required to have a top-level spawner method
Future<Workhorse<P, R>> spawnRunner<P, R>(RunnerBuilder factory) async => throw 'Not implemented for platform';
