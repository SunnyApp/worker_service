library isolate_service;

import 'dart:async';

import 'package:isolate/runner.dart';
import 'package:isolate_service/runners_web.dart';

import 'common.dart';

/// Creates for web
class RunnerFactory {
  /// Adds an initializer - this consumes the [IsolateRunner] and performs some action on it
  void onIsolateCreated(IsolateInitializer init) {}

  /// Adds an initializer - this is run on each isolate that's spawned, and contains any common setup.
  void addIsolateInitializer<P>(RunInsideIsolateInitializer<P> init, P param) {}

  static RunnerFactory global = RunnerFactory();

  IsolateService create([void configure(RunnerBuilder builder)]) {
    return IsolateService(RunnerBuilder._(), Future.value(SameIsolateRunner()));
  }
}

class SameIsolateRunner implements Runner {
  @override
  Future<void> close() async {}

  @override
  Future<R> run<R, P>(FutureOr<R> Function(P argument) function, P argument,
      {Duration timeout, FutureOr<R> Function() onTimeout}) {
    return Future.value(function(argument));
  }
}

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
      return "$_debugName: ${_spawnCount++}";
    } else {
      return "$_debugName";
    }
  }

  /// How many isolates to create in the pool.  If this value is 1, then a single [IsolateRunner] will be created.  Otherwise,
  /// a [LoadBalancer] will be created.  Must be greater than 0
  int poolSize = 1;

  /// Whether to automatically close the underlying isolates then the calling isolate is destroyed.  Default is true.  If you
  /// set this to false, you must call [Runner.close] on your own.
  bool autoclose = true;

  RunnerBuilder._();

  final _onIsolateCreated = <IsolateInitializer>[];
  final _isolateInitializers = <InitializerWithParam>[];

  /// Adds an initializer - this consumes the [IsolateRunner] and performs some action on it
  void onIsolateCreated(IsolateInitializer init) {
    assert(init != null);
    _onIsolateCreated.add(init);
  }

  /// Adds an initializer - this is run on each isolate that's spawned, and contains any common setup.
  void addIsolateInitializer<P>(RunInsideIsolateInitializer<P> init, [P param]) {
    assert(init != null);
    _isolateInitializers.add(InitializerWithParam<P>(param, init));
  }

  Future initialize(Runner target) async {
    try {
      for (final onCreate in _onIsolateCreated) {
        await onCreate(target);
      }

      for (final init in _isolateInitializers) {
        await target.run(init.init, init.param);
      }
    } catch (e) {
      print(e);
      rethrow;
    }
  }
}
