import 'dart:async';

import 'package:isolate/load_balancer.dart';
import 'package:isolate/runner.dart';
import 'package:worker_service/worker_service.dart';

typedef IsolateFunction<P, R> = FutureOr<R> Function(R input);

/// Backed by a [LoadBalancer] isolate pool.
class RunnerBuilder {
  var _spawnCount = 1;

  /// Whether this isolate or pool should fail when an error is encountered.
  bool failOnError = false;

  Duration defaultTimeout = Duration(seconds: 30);

  String get debugNameBase => _debugName;

  void withoutTimeout() {
    defaultTimeout = null;
  }

  /// What to name the isolate that gets created.  If using a pool, an integer will be appended to each isolate that's created
  String _debugName;

  set debugName(String name) {
    _debugName = name;
  }

  String get debugName {
    if (_debugName == null) return null;
    if (poolSize > 1) {
      return '$_debugName: ${_spawnCount++}';
    } else {
      return '$_debugName';
    }
  }

  /// How many isolates to create in the pool.  If this value is 1, then a single [IsolateRunner] will be created.  Otherwise,
  /// a [LoadBalancer] will be created.  Must be greater than 0
  int poolSize = 1;

  /// Whether to automatically close the underlying isolates then the calling isolate is destroyed.  Default is true.  If you
  /// set this to false, you must call [Runner.close] on your own.
  bool autoclose = true;

  RunnerBuilder._();

  final onIsolateCreated = <IsolateInitializer>[];
  final isolateInitializers = <InitializerWithParam>[];

  /// Adds an initializer - this consumes the [IsolateRunner] and performs some action on it
  void addOnIsolateCreated(IsolateInitializer init) {
    assert(init != null);
    onIsolateCreated.add(init);
  }

  /// Adds an initializer - this is run on each isolate that's spawned, and contains any common setup.
  void addIsolateInitializer<P>(RunInsideIsolateInitializer<P> init, [P param]) {
    assert(init != null);
    isolateInitializers.add(InitializerWithParam<P>(param, init));
  }
}

/// Wraps a [Runner] and ensures that it's spawned before executing any operations
class WorkhorseService<P, R> implements Workhorse<P, R> {
  FutureOr<Workhorse<P, R>> _workhorse;
  final RunnerBuilder builder;

  Duration get defaultTimeout => builder.defaultTimeout;

  WorkhorseService(
    this.builder,
    Future<Workhorse<P, R>> workhorse,
  )   : assert(builder != null),
        _workhorse = workhorse {
    workhorse.then((resolved) {
      _workhorse = resolved;
    });
  }

  String get debugName => builder.debugNameBase ?? "unnamedIsolate";

  Future _shutdownFuture;

  @override
  Future close() async {
    return Future.sync(() => _shutdownFuture ??= Future.value(_workhorse).then((_) => _.close()));
  }

//  Future<E> runInService<E>(
//      {FutureOr<E> codeToExecute(IsolateRunner runner),
//      FutureOr<E> codeToExecuteIfLoadBalanced(LoadBalancer runner)}) async {
//    final runner = await _runner;
//
//    if (runner is IsolateRunner) {
//      return Future.sync(() => isolate(runner));
//    } else if (runner is LoadBalancer) {
//      return Future.sync(() => lb(runner));
//    } else {
//      throw "Don't understand type: ${runner.runtimeType}";
//    }
//  }

  Stream<dynamic> get errors async* {
    final workhorse = await _workhorse;
    final stream = getErrorsForRunner(workhorse);

    await for (final e in stream) {
      yield e;
    }
  }

  var i = 0;
  @override
  Future<R> run(job, P argument,
      {String name, Duration timeout, FutureOr<R> onTimeout(), bool ignoreShutdown = false}) async {
    try {
      final workhorse = await _workhorse;
      if (isShuttingDown && ignoreShutdown != true) {
        throw '$debugName: This service is shutting down';
      }
      final res = await Future.sync(() => workhorse.run({"job": job}, argument, timeout: timeout ?? defaultTimeout))
          .catchError((err) {
        print("${name ?? 'unknown'}: isolate: $err");
      });

      return res;
    } catch (e) {
      rethrow;
    }
  }

  Future kill([Duration timeout = const Duration(seconds: 1)]) async {
    final runner = await _workhorse;
    _shutdownFuture = Future.value(killRunner(runner));
    return _shutdownFuture;
  }

  Future<bool> ping([Duration duration = const Duration(seconds: 1)]) async {
    if (isShuttingDown) return false;
    return pingRunner(await _workhorse);
  }

  Future<WorkhorseService<P, R>> ready() async {
    final workhorse = await _workhorse;
    _workhorse = workhorse;
    return this;
  }

  bool get isShuttingDown {
    return _shutdownFuture != null;
  }
}

/// This should be implemented by the platform
Future initializeRunner(RunnerBuilder builder, Runner target) async => throw 'not implemented for this platform';

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

/// Contains the initializers necessary to construct a specific type of isolate.  Any initializers added to
/// [WorkhorseFactory.global] will be applied to all isolates produced by this application.
///
/// To construct an isolate [Runner], call the [create] method, with an optional builder.  eg.
/// ``` dart
/// final IsolateService runner = RunnerFactory.global.create((builder) => builder
///     ..poolSize = 3
///     ..debugName = "widgetMaker"
///     ..autoclose = true
/// );
///
/// await runner.run(...);
///
/// ```
class WorkhorseFactory<R, P> {
  final _onIsolateCreated = <IsolateInitializer>[];
  final _isolateInitializers = <InitializerWithParam>[];

  /// Adds an initializer - this consumes the [IsolateRunner] and performs some action on it
  void onIsolateCreated(
    IsolateInitializer init,
  ) {
    assert(init != null);
    _onIsolateCreated.add(init);
  }

  /// Adds an initializer - this is run on each isolate that's spawned, and contains any common setup.
  void addIsolateInitializer<PP>(RunInsideIsolateInitializer<PP> init, PP param) {
    assert(init != null);
    _isolateInitializers.add(InitializerWithParam<PP>(param, init));
  }

  static WorkhorseFactory global = WorkhorseFactory();

  WorkhorseService<P, R> create([void configure(RunnerBuilder builder)]) {
    final builder = RunnerBuilder._();
    _isolateInitializers.forEach((i) {
      builder.addIsolateInitializer(i.init, i.param);
    });

    _onIsolateCreated.forEach((i) {
      builder.addOnIsolateCreated(i);
    });

    configure?.call(builder);

    return WorkhorseService<P, R>(builder, spawnRunner(builder));
  }
}

class WorkhorseKey<P, R> {
  const WorkhorseKey();
}

/// A worker that's dedicated to doing a certain type of job
abstract class Workhorse<P, R> {
  FutureOr<R> run(job, P params, {Duration timeout, FutureOr<R> Function() onTimeout});
  FutureOr close();
}
