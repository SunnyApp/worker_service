import 'dart:async';

import 'package:isolate/runner.dart';
import 'common.dart';

WorkerServicePlatform workerService() =>
    throw "Not implemented on this platform";

/// Spawns a new isolate with any extra processing.  It's required to have a top-level spawner method
Future<Runner> spawnRunner(RunnerBuilder factory) => throw "Not implemented";
