import 'dart:async';
import 'dart:isolate';

import 'package:isolates/isolates.dart';
import 'package:isolates/runner_factory.dart';
import 'package:logging_config/logging_config.dart';
import 'package:logging_config/logging_environment.dart';
import 'package:worker_service/common.dart';

WorkerServicePlatform workerService() => const WorkerServiceIsolatePlatform();

class WorkerServiceIsolatePlatform implements WorkerServicePlatform {
  @override
  String? get currentIsolateName => Isolate.current.debugName;

  @override
  Stream getErrorsForRunner(Runner runner) {
    if (runner is LoadBalancer) {
      return Stream.empty();
    } else if (runner is IsolateRunner) {
      return runner.errors;
    } else {
      return Stream.empty();
    }
  }

  @override
  bool get isMainIsolate => Isolate.current.debugName == 'main';

  @override
  FutureOr<bool> killRunner(Runner runner,
      {Duration timeout = const Duration(seconds: 1)}) async {
    if (runner is LoadBalancer) {
      await runner.close();
      return true;
    } else if (runner is IsolateRunner) {
      await runner.kill(timeout: timeout);
      return true;
    } else {
      throw 'Invalid isolate type: ${runner.runtimeType}';
    }
  }

  @override
  FutureOr<bool> pingRunner(Runner runner,
      {Duration timeout = const Duration(seconds: 1)}) async {
    if (runner is LoadBalancer) {
      await runner.run(_ping, true, timeout: timeout);
      return true;
    } else if (runner is IsolateRunner) {
      await runner.ping(timeout: timeout);
      return true;
    } else {
      return true;
    }
  }

  const WorkerServiceIsolatePlatform();
}

extension RunnerExtension on Runner {
  Future closeWhenParentIsolateExits() async {
    /// Ensures that the spawned isolates will die when "this" isolate dies.
    final self = this;
    final current = Isolate.current;

    /// Ensures that the spawned isolates will die when "this" isolate dies.
    await singleResponseFuture(current.addOnExitListener);
    return await self.close();
  }
}

Future<Runner> spawnRunner(RunnerBuilder builder) async {
  final spawner = () => IsolateRunner.build(builder);
  Runner result;
  if (builder.poolSize == 1) {
    /// Create a single runner
    result = await spawner();
  } else if (builder.poolSize > 1) {
    result = await LoadBalancer.create(builder.poolSize, spawner);
  } else {
    throw 'Invalid runner configuration.  Pool size must be at least 1';
  }

  if (builder.autoCloseChildren) {
    result.closeWhenParentIsolateExits();
  }
  return result;
}

R _ping<R>(R _) {
  return _;
}

// /// Creates a single [IsolateRunner]
// ///
// /// This code was copied from the `isolate` library, to allow for injecting initialization and tear down.
// Future<IsolateRunner> spawnSingleRunner(RunnerBuilder factory) async {
//   var initialPortGetter = SingleResponseChannel();
//   var isolate = await Isolate.spawn(_create, initialPortGetter.port,
//       debugName: factory.debugName);
//
//   // Whether an uncaught exception should kill the isolate
//   isolate.setErrorsFatal(factory.failOnError);
//   var pingChannel = SingleResponseChannel();
//   isolate.ping(pingChannel.port);
//   var commandPort = (await initialPortGetter.result as SendPort);
//   var result = IsolateRunner(isolate, commandPort);
//
//   try {
//     await _initializeIsolateRunner(factory, result);
//   } catch (e, stack) {
//     print(stack);
//     await result.close();
//     rethrow;
//   }
//
//   // Guarantees that setErrorsFatal has completed.
//   await pingChannel.result;
//
//   if (factory.autoclose) {
//     // I tried using my own channel for this
//     final shutdownResponse = SingleResponseChannel(callback: (_) {
//       print(
//           '############  SHUTDOWN ${factory.debugNameBase}  ##################');
//     });
//     Isolate.current.addOnExitListener(commandPort,
//         response: [_SHUTDOWN, shutdownResponse.port]);
//   }
//
//   return result;
// }

IsolateLoggingEnvironment workerLogEnvironment() {
  return const IsolateLoggingEnvironment();
}

class IsolateLoggingEnvironment implements LoggingEnvironment {
  const IsolateLoggingEnvironment();

  @override
  String get envName => "${Isolate.current.debugName ?? 'main'}";

  @override
  void onLogConfig(LogConfig logConfig) {
    RunnerFactory.global
        .addIsolateInitializerParam(_configureLoggingIsolate, logConfig);
  }
}

/// Required to have a top-level global function to pass to the isolate
FutureOr _configureLoggingIsolate(final dynamic p) async {
  if (p is LogConfig) return await configureLogging(p);
}
