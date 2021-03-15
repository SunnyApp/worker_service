import 'dart:async';

abstract class Runner {
  Future<void> close();

  Future<R> run<R, P>(FutureOr<R> Function(P argument) function, P argument,
      {Duration? timeout, FutureOr<R> Function()? onTimeout});
}
