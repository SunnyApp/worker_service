import 'dart:async';

import 'package:isolates/runner.dart';
import 'package:isolates/runner_factory.dart';
import 'package:logging_config/logging_environment.dart';
import 'common.dart';

WorkerServicePlatform workerService() =>
    throw "Not implemented on this platform";

/// Spawns a new isolate with any extra processing.  It's required to have a top-level spawner method
Future<Runner> spawnRunner(RunnerBuilder factory) => throw "Not implemented";

LoggingEnvironment workerLogEnvironment() => throw "Not implemented";
