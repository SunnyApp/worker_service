import 'dart:async';
import 'dart:isolate';

import 'package:isolate/isolate.dart';

/// Wraps a [Runner] and ensures that it's spawned before executing any operations
class IsolateService implements Runner {
  FutureOr<Runner> _runner;
  final Duration defaultTimeout;
  IsolateService(Future<Runner> spawner, this.defaultTimeout)
      : _runner = spawner {
    spawner.then((resolved) {
      _runner = resolved;
    });
  }

  Future _shutdownFuture;

  Runner get runner => _runner as Runner;

  @override
  Future close() async {
    return _shutdownFuture ??= (await _runner).close();
  }

  FutureOr<E> withRunner<E>(
      {FutureOr<E> isolate(IsolateRunner runner),
      FutureOr<E> lb(LoadBalancer runner)}) {
    final r = _runner;

    FutureOr<E> _(final Runner runner) {
      if (runner is IsolateRunner) {
        return isolate(runner);
      } else if (runner is LoadBalancer) {
        return lb(runner);
      } else {
        throw "Don't understand type: ${runner.runtimeType}";
      }
    }

    if (r is Future<Runner>) {
      return r.then(_);
    } else {
      return _(r as Runner);
    }
  }

  Stream<dynamic> get errors async* {
    final stream = await withRunner(
        isolate: (isolate) => isolate.errors, lb: (lb) => Stream.empty());
    await for (final e in stream) {
      yield e;
    }
  }

  @override
  Future<R> run<R, P>(FutureOr<R> Function(P argument) function, P argument,
      {Duration timeout,
      FutureOr<R> Function() onTimeout,
      bool ignoreShutdown = false}) async {
    final r = await _runner;
    if (isShuttingDown && !ignoreShutdown) {
      throw "This service is shutting down";
    }
    return withRunner<R>(
        lb: (lb) {
          if (lb.length == 0) {
            throw "No active isolates";
          }
          return lb.run(function, argument,
              timeout: timeout ?? defaultTimeout, onTimeout: onTimeout);
        },
        isolate: (i) => i.run(function, argument,
            timeout: timeout ?? defaultTimeout, onTimeout: onTimeout));
  }

  Future kill([Duration timeout = const Duration(seconds: 1)]) {
    _shutdownFuture = withRunner(
        lb: (lb) => runner.close(), isolate: (i) => i.kill(timeout: timeout));
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

  Future<IsolateService> ready() {
    final runner = _runner;
    if (runner is Future<Runner>) {
      return runner.then((_) {
        _runner = _;
        return this;
      });
    } else {
      return Future.value(this);
    }
  }

  @override
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

  Future<O> execute<Null, O>(FutureOr<O> block(Null v),
      {Duration timeout, FutureOr<O> onTimeout()}) async {
    return await this.run(block, null, timeout: timeout, onTimeout: onTimeout);
  }
}

typedef IsolateFunction<P, R> = FutureOr<R> Function(R input);

extension FutureExt on Future {
  ignored() {}
}
