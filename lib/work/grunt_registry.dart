import 'package:logging/logging.dart';

import 'grunt.dart';
import 'message.dart';

// ignore: non_constant_identifier_names
var _gruntRegistry = _GruntRegistry._();
_GruntRegistry get gruntRegistry => _gruntRegistry;
set gruntRegistry(_GruntRegistry registry) {
  _gruntRegistry = registry;
}

typedef GruntFactoryFn<G extends Grunt> = G Function();

abstract class GruntFactory<G extends Grunt> {
  String get key;
  String? get package;
  GruntFactoryFn<G> get create;

  /// The encoding you use for this type of operation
  PayloadHandler get encoding => PayloadHandler.defaults;

  const GruntFactory();
  const factory GruntFactory.of(String key, GruntFactoryFn<G> create,
      [String? package]) = _GruntFactory;
}

extension GruntFactoryRegister on GruntFactory {
  void register() {
    gruntRegistry += this;
  }
}

class _GruntFactory<G extends Grunt> extends GruntFactory<G> {
  @override
  final GruntFactoryFn<G> create;

  @override
  final String key;

  @override
  final String? package;

  const _GruntFactory(this.key, this.create, [this.package]) : super();
}

class _GruntRegistry {
  static final log = Logger("gruntRegistry");

  _GruntRegistry._();

  final _factories = <String, GruntFactory>{};

  _GruntRegistry operator +(GruntFactory factory) {
    final key = factory.key;
    if (_factories.containsKey(key)) {
      log.warning("Grunt key already exists!: $key");
    }
    _factories[key] = factory;
    return this;
  }

  GruntFactory operator [](String key) {
    return _factories[key] ??
        (throw Exception("Factory not found for key $key"));
  }
}
