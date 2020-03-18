import 'dart:async';

export "runner_factory.dart" if (dart.library.js) "runner_factory_web.dart" if (dart.library.io) "runner_factory.dart";
export "runners_isolate.dart" if (dart.library.js) "runners_web.dart" if (dart.library.io) "runners_isolate.dart";

typedef IsolateFunction<P, R> = FutureOr<R> Function(R input);

extension FutureExt on Future {
  ignored() {}
}
