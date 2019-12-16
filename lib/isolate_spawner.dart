import 'dart:async';
import 'dart:isolate';

import 'package:isolate/isolate.dart';
import 'package:isolate/isolate_runner.dart';

import 'runner_factory.dart';

/// Produces IsolateRunner instances, including any initialization to the isolate(s) created.
typedef IsolateRunnerFactory = Future<IsolateRunner> Function();

/// Given a newly created [IsolateRunner], ensures that the isolate(s) that back the [IsolateRunner] are
/// initialized properly
typedef IsolateInitializer = FutureOr Function(IsolateRunner runner);

/// Initializer that runs inside the isolate.
typedef RunInsideIsolateInitializer<P> = FutureOr Function(P param);

class InitializerWithParam<P> {
  final P param;
  final RunInsideIsolateInitializer<P> init;

  InitializerWithParam(this.param, this.init);
}

/// Spawns a new isolate with any extra processing.  It's required to have a top-level spawner method
IsolateRunnerFactory spawnIsolate(RunnerBuilder factory) =>
    (() => _spawn(factory));

/// Creates a single [IsolateRunner]
///
/// This code was copied from the `isolate` library, to allow for injecting initialization and tear down.
Future<IsolateRunner> _spawn(RunnerBuilder factory) async {
  var channel = SingleResponseChannel();
  var isolate =
      await Isolate.spawn(_create, channel.port, debugName: factory.debugName);

  // The runner can be used to run multiple independent functions.
  // An accidentally uncaught error shouldn't ruin it for everybody else.
  isolate.setErrorsFatal(factory.failOnError);
  var pingChannel = SingleResponseChannel();
  isolate.ping(pingChannel.port);
  var commandPort = (await channel.result as SendPort);
  var result = IsolateRunner(isolate, commandPort);

  try {
    await factory.initialize(result);
  } catch (e, stack) {
    print(stack);
    rethrow;
  }
  // Guarantees that setErrorsFatal has completed.
  await pingChannel.result;

  // Not sure why this work...
//  if (factory.autoclose) {
//    final shutdownChannel = SingleResponseChannel();
//    Isolate.current.addOnExitListener(commandPort,
//        response: List(2)
//          ..[0] = _SHUTDOWN
//          ..[1] = shutdownChannel.port);
//    shutdownChannel.result.then((result) {
//      print("Got kill signal");
//    }).ignored();
//  }
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
