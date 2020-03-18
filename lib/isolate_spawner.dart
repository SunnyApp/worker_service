import 'dart:async';
import 'dart:isolate';

import 'package:isolate/isolate.dart';
import 'package:isolate/isolate_runner.dart';

import 'common.dart';
import 'runner_factory.dart';

/// Spawns a new isolate with any extra processing.  It's required to have a top-level spawner method
IsolateRunnerFactory spawnIsolate(RunnerBuilder factory) => (() => _spawn(factory));

/// Creates a single [IsolateRunner]
///
/// This code was copied from the `isolate` library, to allow for injecting initialization and tear down.
Future<IsolateRunner> _spawn(RunnerBuilder factory) async {
  var channel = SingleResponseChannel();
  var isolate = await Isolate.spawn(_create, channel.port, debugName: factory.debugName);

  // Whether an uncaught exception should kill the isolate
  isolate.setErrorsFatal(factory.failOnError);
  var pingChannel = SingleResponseChannel();
  isolate.ping(pingChannel.port);
  var commandPort = (await channel.result as SendPort);
  var result = IsolateRunner(isolate, commandPort);

  try {
    await factory.initialize(result);
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
      print("############  SHUTDOWN ${factory.debugNameBase}  ##################");
    });
    Isolate.current.addOnExitListener(commandPort, response: [_SHUTDOWN, shutdownResponse.port]);
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
