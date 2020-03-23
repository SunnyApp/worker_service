import 'dart:async';
import 'dart:isolate';

import 'package:isolate/isolate.dart';
import 'package:isolate/isolate_runner.dart';
import 'package:worker_service/common.dart';

String get currentIsolateName {
  return Isolate.current.debugName;
}

bool get isMainIsolate {
  return Isolate.current.debugName == 'main';
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
  final spawner = () => spawnSingleRunner(builder);
  Runner result;
  if (builder.poolSize == 1) {
    /// Create a single runner
    result = await spawner();
  } else if (builder.poolSize > 1) {
    result = await LoadBalancer.create(builder.poolSize, spawner);
  } else {
    throw 'Invalid runner configuration.  Pool size must be at least 1';
  }

  if (builder.autoclose) {
    result.closeWhenParentIsolateExits().ignored();
  }
  return result;
}

Stream<dynamic> getErrorsForRunner(Runner runner) {
  if (runner is LoadBalancer) {
    return Stream.empty();
  } else if (runner is IsolateRunner) {
    return runner.errors;
  } else {
    return Stream.empty();
  }
}

R _ping<R>(R _) {
  return _;
}

FutureOr<bool> pingRunner(Runner runner, {Duration timeout}) async {
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

FutureOr<bool> killRunner(Runner runner, {Duration timeout}) async {
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

/// Creates a single [IsolateRunner]
///
/// This code was copied from the `isolate` library, to allow for injecting initialization and tear down.
Future<IsolateRunner> spawnSingleRunner(RunnerBuilder factory) async {
  var channel = SingleResponseChannel();
  var isolate =
      await Isolate.spawn(_create, channel.port, debugName: factory.debugName);

  // Whether an uncaught exception should kill the isolate
  isolate.setErrorsFatal(factory.failOnError);
  var pingChannel = SingleResponseChannel();
  isolate.ping(pingChannel.port);
  var commandPort = (await channel.result as SendPort);
  var result = IsolateRunner(isolate, commandPort);

  try {
    await _initializeIsolateRunner(factory, result);
  } catch (e, stack) {
    print(stack);
    await result.close();
    rethrow;
  }
  // Guarantees that setErrorsFatal has completed.
  await pingChannel.result;

  if (factory.autoclose) {
    // I tried using my own channel for this
    final shutdownResponse = SingleResponseChannel(callback: (_) {
      print(
          '############  SHUTDOWN ${factory.debugNameBase}  ##################');
    });
    Isolate.current.addOnExitListener(commandPort,
        response: [_SHUTDOWN, shutdownResponse.port]);
  }

  return result;
}

const _SHUTDOWN = 0;

/// This code is run inside the isolate when it's first created.
///
/// Copied from `isolate` library
void _create(Object data) {
  var initPort = data as SendPort;
  var remote = IsolateRunnerRemote();
  initPort.send(remote.commandPort);
}

Future _initializeIsolateRunner(
    RunnerBuilder builder, IsolateRunner target) async {
  try {
    for (final onCreate in builder.onIsolateCreated) {
      await onCreate(target);
    }

    for (final init in builder.isolateInitializers) {
      await target.run(init.init, init.param);
    }
  } catch (e) {
    print(e);
    rethrow;
  }
}
