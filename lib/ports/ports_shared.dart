import 'dart:async';

import 'package:async/async.dart';
import 'package:worker_service/ports/ports.dart';

class ProxyReceivePort extends DelegatingStream
    with ReceivePort2
    implements SendPort2 {
  final StreamController _ctl;

  ProxyReceivePort._(this._ctl) : super(_ctl.stream);

  ProxyReceivePort() : this._(StreamController(sync: true));

  @override
  void send(Object message) {
    _ctl.add(message);
  }

  @override
  void close() {
    _ctl.close();
  }

  @override
  SendPort2 get sendPort => this;
}
