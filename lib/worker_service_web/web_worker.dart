@JS()
library web_worker;

import 'dart:html';

import 'package:js/js.dart';

import 'common_web.dart';

@JS('self')
external DedicatedWorkerGlobalScope get self;

void main() {
  print('Worker created');
  self.onMessage.listen((MessageEvent event) {
    final invoker = RunnerInvocation.ofEventData(event.data);
    try {
      final result = invoker.function?.call(invoker.argument);
      self.postMessage(RunnerInvocationResult.success(invoker.id, result));
    } catch (e) {
      self.postMessage(RunnerInvocationResult.executionFailure(invoker.id, e));
    }
  }, cancelOnError: false);
}
