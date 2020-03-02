import 'dart:async';
import 'dart:isolate';

import 'package:isolate/isolate.dart';
import 'package:isolate_service/runner_factory.dart';

/// Wraps a [Runner] and ensures that it's spawned before executing any operations
class IsolateService implements Runner {
  FutureOr<Runner> _runner;
  final RunnerBuilder builder;

  Duration get defaultTimeout => builder.defaultTimeout;

  IsolateService(
    this.builder,
    Future<Runner> spawner,
  )   : assert(builder != null),
        _runner = spawner {
    spawner.then((resolved) {
      _runner = resolved;
    });
  }

  String get debugName => builder.debugNameBase ?? "unnamedIsolate";

  Future _shutdownFuture;

  @override
  Future close() async {
    return Future.sync(() async => _shutdownFuture ??= (await _runner).close());
  }

  Future<E> withRunner<E>({FutureOr<E> isolate(IsolateRunner runner), FutureOr<E> lb(LoadBalancer runner)}) async {
    final runner = await _runner;
    if (runner is IsolateRunner) {
      return Future.sync(() => isolate(runner));
    } else if (runner is LoadBalancer) {
      return Future.sync(() => lb(runner));
    } else {
      throw "Don't understand type: ${runner.runtimeType}";
    }
  }

  Stream<dynamic> get errors async* {
    final Stream stream = await withRunner(isolate: (isolate) => isolate.errors, lb: (lb) => Stream.empty());
    await for (final e in stream) {
      yield e;
    }
  }

  var i = 0;
  @override
  Future<R> run<R, P>(FutureOr<R> Function(P argument) function, P argument,
      {String name, Duration timeout, FutureOr<R> onTimeout(), bool ignoreShutdown = false}) async {
    try {
      final runner = await _runner;
      if (isShuttingDown && ignoreShutdown != true) {
        throw "$debugName: This service is shutting down";
      }
      final res = await Future.sync(
              () => runner.run(function, argument, timeout: timeout ?? defaultTimeout, onTimeout: onTimeout))
          .catchError((err) {
        print("${name ?? 'unknown'}: isolate: $err");
      });

      return res;
    } catch (e) {
      rethrow;
    }
  }

  Future kill([Duration timeout = const Duration(seconds: 1)]) {
    final _shutdownFuture = Future.sync(
      () => withRunner(
        lb: (lb) => lb.close(),
        isolate: (i) => i.kill(timeout: timeout),
      ),
    );
    this._shutdownFuture = _shutdownFuture;
    return _shutdownFuture;
  }

  Future<bool> ping([Duration duration = const Duration(seconds: 1)]) async {
    if (isShuttingDown) return false;

    return await withRunner<bool>(
      lb: (lb) async {
        return await lb.run(_ping, true, timeout: duration);
      },
      isolate: (i) => i.ping(timeout: duration),
    );
  }

  Future<IsolateService> ready() async {
    final runner = await _runner;
    _runner = runner;
    return this;
  }

  bool get isShuttingDown {
    return _shutdownFuture != null;
  }
}

R _ping<R>(R _) {
  return _;
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

typedef IsolateFunction<P, R> = FutureOr<R> Function(R input);

extension FutureExt on Future {
  ignored() {}
}
