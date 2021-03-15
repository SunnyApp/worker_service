import 'dart:async';

import 'package:isolates/isolates.dart';
import 'package:isolates/runner_factory.dart';

import 'work/work.dart';
import 'worker_service_interface.dart'
    if (dart.library.io) 'worker_service_isolate.dart'
    if (dart.library.js) 'worker_service_web/worker_service_web.dart';

typedef IsolateFunction<P, R> = FutureOr<R> Function(R input);

/// Represents the abstraction between platforms
abstract class WorkerServicePlatform {
  Stream<dynamic> getErrorsForRunner(Runner runner);

  FutureOr<bool> pingRunner(Runner runner, {Duration timeout});

  FutureOr<bool> killRunner(Runner runner, {Duration timeout});

  String? get currentIsolateName;

  bool get isMainIsolate;
}

/// Wraps a [Runner] and ensures that it's spawned before executing any operations
class RunnerService implements Runner {
  static final platform = workerService();
  FutureOr<Runner> _runner;
  final RunnerBuilder builder;

  Duration? get defaultTimeout => builder.defaultTimeout;

  RunnerService(
    this.builder,
    Future<Runner> spawner,
  ) : _runner = spawner {
    spawner.then((resolved) {
      _runner = resolved;
    });
  }

  String get debugName => builder.debugNameBase ?? "unnamedIsolate";

  Future? _shutdownFuture;

  @override
  Future close() async {
    return Future.sync(() async => _shutdownFuture ??= (await _runner).close());
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
    final runner = await _runner;
    final stream = platform.getErrorsForRunner(runner);

    await for (final e in stream) {
      yield e;
    }
  }

  var i = 0;

  Future<Work?> submit<ParamType>(String key, ParamType params) async {
    return null;
  }

  @override
  Future<R> run<R, P>(FutureOr<R> Function(P argument) function, P argument,
      {String? name,
      Duration? timeout,
      FutureOr<R> onTimeout()?,
      bool ignoreShutdown = false}) async {
    try {
      final runner = await _runner;
      if (isShuttingDown && ignoreShutdown != true) {
        throw '$debugName: This service is shutting down';
      }
      final res = await Future.sync(() => runner.run(function, argument,
          timeout: timeout ?? defaultTimeout,
          onTimeout: onTimeout)).catchError((err) {
        print("${name ?? 'unknown'}: isolate: $err");
      });

      return res;
    } catch (e, stack) {
      print(stack);
      rethrow;
    }
  }

  Future? kill([Duration timeout = const Duration(seconds: 1)]) async {
    final runner = await _runner;
    _shutdownFuture = Future.value(platform.killRunner(runner));
    return _shutdownFuture;
  }

  Future<bool> ping([Duration duration = const Duration(seconds: 1)]) async {
    if (isShuttingDown) return false;
    return platform.pingRunner(await _runner);
  }

  Future<RunnerService> ready() async {
    final runner = await _runner;
    _runner = runner;
    return this;
  }

  bool get isShuttingDown {
    return _shutdownFuture != null;
  }
}

/// This should be implemented by the platform
Future initializeRunner(RunnerBuilder builder, Runner target) async =>
    throw 'not implemented for this platform';

/// Contains the initializers necessary to construct a specific type of isolate.  Any initializers added to
/// [RunnerFactory.global] will be applied to all isolates produced by this application.
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
class RunnerFactory {
  final _onIsolateCreated = <IsolateInitializer>[];
  final _isolateInitializers = <InitializerWithParam>[];

  List<InitializerWithParam> get isolateInitializers => _isolateInitializers;

  void reset() {
    _onIsolateCreated.clear();
    _isolateInitializers.clear();
  }

  /// Adds an initializer - this consumes the [IsolateRunner] and performs some action on it
  void onIsolateCreated(
    IsolateInitializer init,
  ) {
    _onIsolateCreated.add(init);
  }

  /// Adds an initializer - this is run on each isolate that's spawned, and contains any common setup.
  void addIsolateInitializerParam<P>(
      RunInsideIsolateInitializer<P> init, P param) {
    _isolateInitializers.add(InitializerWithParam.of<P>(param, init));
  }

  /// Adds an initializer - this is run on each isolate that's spawned, and contains any common setup.
  void addIsolateInitializerDeferred<P>(
      RunInsideIsolateInitializer<P> init, P param()) {
    _isolateInitializers.add(InitializerWithParam<P>(param, init));
  }

  /// Adds an initializer - this is run on each isolate that's spawned, and contains any common setup.
  void addIsolateInitializer(void init()) {
    _isolateInitializers.add(InitializerWithParam.noParam(init));
  }

  static RunnerFactory global = RunnerFactory();

  RunnerService create([void configure(RunnerBuilder builder)?]) {
    final builder = RunnerBuilder.defaults();
    _isolateInitializers.forEach((i) {
      builder.addIsolateInitializerWithDeferredParam(i.init, i.param);
    });

    _onIsolateCreated.forEach((i) {
      builder.addOnIsolateCreated(i);
    });

    configure?.call(builder);

    return RunnerService(builder, spawnRunner(builder));
  }
}
