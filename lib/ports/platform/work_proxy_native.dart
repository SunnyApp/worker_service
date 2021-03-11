// ignore_for_file: always_require_non_null_named_parameters

import 'dart:async';
import 'dart:html' as web;
import 'dart:isolate';
import 'package:async/async.dart';
import 'package:isolate/isolate.dart';
import 'package:sunny_dart/helpers.dart';
import 'package:worker_service/ports/isolate_entry.dart';
import 'package:worker_service/ports/ports.dart';
import 'package:worker_service/ports/ports_shared.dart';

Future<WorkIsolate> spawnWorkProxy(IsolateEntry entry,
    {bool errorsAreFatal = true, String? debugName}) async {
  var recv = ProxyReceivePort();

  /// Pass the
  final isolate = await Isolate.spawn(entry.entryFunction!, recv.sendPort,
      onExit: SendPortBridge(recv.sendPort),
      onError: SendPortBridge(recv.sendPort));

  return WorkProxyIsolate(worker: isolate, rcp: recv);
}

class IsolateSendPort implements SendPort2 {
  final SendPort sendPort;

  const IsolateSendPort(this.sendPort);

  @override
  void send(Object? message) {
    sendPort.send(message);
  }
}

class SendPortBridge implements SendPort {
  final SendPort2 delegate;

  SendPortBridge(this.delegate);

  @override
  void send(Object? message) {
    delegate.send(message);
  }

  @override
  int get hashCode {
    return delegate.hashCode;
  }

  @override
  bool operator ==(Object other) {
    return delegate == other;
  }
}

class WorkProxyIsolate extends WorkIsolate {
  final Isolate worker;
  final ReceivePort2 rcp;

  WorkProxyIsolate({required this.worker, required this.rcp, bool errorsAreFatal = true})
      : assert(worker != null),
        assert(errorsAreFatal != null),
        super(rcp.sendPort);

  @override
  void addErrorListener(SendPort2 port) {
    worker.addErrorListener(SendPortBridge(port));
  }

  @override
  void addOnExitListener(SendPort2 responsePort, {Object? response}) {
    worker.addOnExitListener(SendPortBridge(responsePort), response: response);
  }

  @override
  String? get debugName => worker.debugName;

  @override
  void kill({int priority = WorkIsolate.beforeNextEvent}) {
    worker.kill(priority: priority);
  }

  @override
  Capability2 pause([Capability2? resumeCapability]) => throw "na";

  @override
  Capability2? get pauseCapability => null;

  @override
  void ping(SendPort2 responsePort,
      {Object? response, int priority = WorkIsolate.immediate}) {
    worker.ping(SendPortBridge(responsePort),
        response: response, priority: priority);
  }

  @override
  void removeErrorListener(SendPort2 port) {
    worker.removeErrorListener(SendPortBridge(port));
  }

  @override
  void removeOnExitListener(SendPort2 responsePort) {
    worker.removeOnExitListener(SendPortBridge(responsePort));
  }

  @override
  void resume(Capability2 resumeCapability) {
    /// do nothing
  }

  @override
  Capability2? get terminateCapability => null;

  @override
  Stream get messages {
    return rcp;
  }
}
