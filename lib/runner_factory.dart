library isolate_service;

import 'dart:async';
import 'dart:isolate';

import 'package:isolate/isolate.dart';
import 'package:isolate/load_balancer.dart';
import 'package:isolate_service/isolate_spawner.dart';
import 'package:isolate_service/runner_service.dart';

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

  /// Adds an initializer - this consumes the [IsolateRunner] and performs some action on it
  void onIsolateCreated(
    IsolateInitializer init,
  ) {
    assert(init != null);
    _onIsolateCreated.add(init);
  }

  /// Adds an initializer - this is run on each isolate that's spawned, and contains any common setup.
  void addIsolateInitializer<P>(RunInsideIsolateInitializer<P> init, P param) {
    assert(init != null);
    _isolateInitializers.add(InitializerWithParam<P>(param, init));
  }

  static RunnerFactory global = RunnerFactory();

  IsolateService create([void configure(RunnerBuilder builder)]) {
    final builder = RunnerBuilder._();
    this._isolateInitializers.forEach((i) {
      builder.addIsolateInitializer(i.init, i.param);
    });

    this._onIsolateCreated.forEach((i) {
      builder.onIsolateCreated(i);
    });

    configure?.call(builder);

    return IsolateService(_spawn(builder), builder.defaultTimeout);
  }

  Future<Runner> _spawn(RunnerBuilder builder) async {
    final spawner = spawnIsolate(builder);
    Runner result;
    if (builder.poolSize == 1) {
      /// Create a single runner
      result = await spawner();
    } else if (builder.poolSize > 1) {
      result = await LoadBalancer.create(builder.poolSize, spawner);
    } else {
      throw "Invalid runner configuration.  Pool size must be at least 1";
    }

    if (builder.autoclose) {
      result.closeWhenParentIsolateExits().ignored();
    }
    return result;
  }
}

/// Backed by a [LoadBalancer] isolate pool.
class RunnerBuilder {
  var _spawnCount = 1;

  /// Whether this isolate or pool should fail when an error is encountered.
  bool failOnError = true;

  Duration defaultTimeout = Duration(seconds: 30);

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
  void addIsolateInitializer<P>(RunInsideIsolateInitializer<P> init,
      [P param]) {
    assert(init != null);
    _isolateInitializers.add(InitializerWithParam<P>(param, init));
  }

  Future initialize(IsolateRunner target) async {
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
