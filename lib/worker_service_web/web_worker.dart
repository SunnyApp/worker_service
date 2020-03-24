@JS()
library web_worker;

import 'package:js/js.dart';

import 'common_web.dart';

@JS('postMessage')
external void postMessage(message);

@JS('onmessage')
external set onMessage(message);

@anonymous
@JS()
abstract class MessageEvent {
  external dynamic get data;
}

void main() {
  print('Worker created');

  // 'allowInterop' is necessary to pass a function into js.
  onMessage = allowInterop((event) {
    var e = event as MessageEvent;
    final invoker = e.data as RunnerInvocation;
    try {
      final result = invoker.function?.call(invoker.argument);
      postMessage(RunnerInvocationResult.success(invoker.id, result));
    } catch (e) {
      postMessage(RunnerInvocationResult.executionFailure(invoker.id, e));
    }
  });
}
