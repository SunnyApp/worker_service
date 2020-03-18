import 'dart:async';

import 'package:isolate/isolate.dart';
import 'package:isolate_service/runner_factory_web.dart';

String get currentIsolateName {
  return "mainWeb";
}

bool get isMainIsolate {
  return true;
}

/// Wraps a [Runner] and ensures that it's spawned before executing any operations
class IsolateService implements Runner {
  FutureOr<Runner> _runner;
  final RunnerBuilder builder;

  Duration get defaultTimeout => builder.defaultTimeout;

  IsolateService(this.builder, Future<Runner> spawner)
      : assert(builder != null),
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

  Future<E> withRunner<E>({FutureOr<E> isolate(Runner runner), FutureOr<E> lb(LoadBalancer runner)}) async {
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
    final Stream stream = await withRunner(
        isolate: (isolate) {
          return isolate is IsolateRunner ? isolate.errors : Stream.empty();
        },
        lb: (lb) => Stream.empty());
    await for (final e in stream) {
      yield e;
    }
  }

  var i = 0;
  @override
  Future<R> run<R, P>(FutureOr<R> Function(P argument) function, P argument,
      {String name, Duration timeout, FutureOr<R> onTimeout(), bool ignoreShutdown = false}) async {
    try {
      return function(argument);
    } catch (e) {
      rethrow;
    }
  }

  Future kill([Duration timeout = const Duration(seconds: 1)]) async {}

  Future<bool> ping([Duration duration = const Duration(seconds: 1)]) async {
    return true;
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

typedef IsolateFunction<P, R> = FutureOr<R> Function(R input);

extension FutureExt on Future {
  ignored() {}
}
