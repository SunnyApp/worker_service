import 'dart:async';

import 'package:isolate/isolate_runner.dart';
import 'package:isolate/runner.dart';

/// Produces IsolateRunner instances, including any initialization to the isolate(s) created.
typedef IsolateRunnerFactory = Future<Runner> Function();

/// Given a newly created [IsolateRunner], ensures that the isolate(s) that back the [Runner] are
/// initialized properly
typedef IsolateInitializer = FutureOr Function(Runner runner);

/// Initializer that runs inside the isolate.
typedef RunInsideIsolateInitializer<P> = FutureOr Function(P param);

class InitializerWithParam<P> {
  final P param;
  final RunInsideIsolateInitializer<P> init;

  InitializerWithParam(this.param, this.init);
}
