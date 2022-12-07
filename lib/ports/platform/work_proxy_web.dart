// ignore_for_file: always_require_non_null_named_parameters

import 'dart:async';
import 'dart:html' as web;
import 'package:equatable/equatable.dart';
import 'package:worker_service/ports/isolate_entry.dart';
import 'package:worker_service/ports/ports.dart';

import '../../utils.dart';

Future<WorkIsolate> spawnWorkProxy<T>(IsolateEntry entry, T message,
    {bool errorsAreFatal = true, String? debugName}) async {
  var worker = web.Worker(entry.entryFileName!);
  var isolate = IsolateWeb(
    worker: worker,
    errorsAreFatal: errorsAreFatal,
    debugName: debugName,
  );

  return isolate;
}

class WebWorkerSendPort extends Equatable implements SendPort2 {
  final String _uuid;
  final web.Worker worker;

  WebWorkerSendPort(this.worker) : _uuid = uuid();

  @override
  void send(Object? message) {
    worker.postMessage(message);
  }

  @override
  List<Object> get props => [_uuid];
}
//
//
// class WebReceivePort extends DelegatingStream with ReceivePort2 {
//   @override
//   final SendPort2 sendPort;
//   final web.Worker worker;
//
//   WebReceivePort(this.worker)
//       : sendPort = WebSendPort(worker),
//         super(worker.onMessage);
//
//   @override
//   void close() {}
// }

class IsolateWeb extends WorkIsolate {
  final web.Worker worker;

  var _isActive = true;
  bool errorsAreFatal;

  final List<SendPort2> _errorLx = [];
  final Map<SendPort2, Object> _exitLx = {};

  IsolateWeb({
    required this.worker,
    this.errorsAreFatal = true,
    this.debugName,
  }) : super(WebWorkerSendPort(worker));

  @override
  void addErrorListener(SendPort2 port) {
    if (!_errorLx.contains(port)) {
      _errorLx.add(port);
    }
  }

  @override
  void addOnExitListener(SendPort2 responsePort, {Object? response}) {
    _exitLx[responsePort] = response ?? true;
  }

  @override
  final String? debugName;

  @override
  void kill({int priority = WorkIsolate.beforeNextEvent}) {
    if (_isActive) {
      _isActive = false;

      worker.terminate();
      _exitLx.forEach((key, value) {
        key.send(value);
      });
    }
  }

  @override
  Capability2 pause([Capability2? resumeCapability]) => throw "Not implemented";

  @override
  Capability2? get pauseCapability => null;

  @override
  void ping(SendPort2 responsePort,
      {Object? response, int priority = WorkIsolate.immediate}) {
    responsePort.send(response ?? true);
  }

  @override
  void removeErrorListener(SendPort2 port) {
    _errorLx.remove(port);
  }

  @override
  void removeOnExitListener(SendPort2 responsePort) {
    _exitLx.remove(responsePort);
  }

  @override
  void resume(Capability2 resumeCapability) {
    /// do nothing
  }

  @override
  void setErrorsFatal(bool errorsAreFatal) {
    this.errorsAreFatal = errorsAreFatal;
  }

  @override
  Capability2? get terminateCapability => null;

  @override
  Stream get messages {
    return worker.onMessage;
  }
}
