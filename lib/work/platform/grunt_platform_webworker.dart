@JS()
library grunt_platform_webworker;

import 'dart:async';

import 'dart:html';

import 'package:js/js.dart';
import 'package:logging/logging.dart';
import 'package:worker_service/work/grunt_channel.dart';

import '../message.dart';

@JS('onmessage')
external set onMessage(f);

@JS('postMessage')
external void postMessage(message, [args]);

@JS("XMLHttpRequestProgressEvent")
abstract class XMLHttpRequestProgressEvent implements ProgressEvent {
  // To suppress missing implicit constructor warnings.
  factory XMLHttpRequestProgressEvent._() {
    throw UnsupportedError("Not supported");
  }
}

class WWDuplexChannel extends DuplexChannel {
  final Logger log;
  final _inbound = StreamController<DecodedMessage>.broadcast();
  @override
  final PayloadHandler encoding;

  WWDuplexChannel(this.encoding, {String? channelName})
      : log = Logger(channelName ?? 'webworker') {
    log.info("Inside web worker, setting up onmessage listener for supervisor");
    onMessage = allowInterop((event) {
      try {
        if (event is MessageEvent) {
          log.info("WebWorker received raw message: ${event.data}");
          _inbound.add(DecodedMessage.decoded(event.data, encoding));
        } else {
          log.warning("Got non-message event: $event");
        }
      } catch (e, stack) {
        log.severe("ERROR LISTENING TO EVENT: $e", e, stack);
      }
    });
  }

  @override
  void close() {
    _inbound.close();
  }

  @override
  Stream<DecodedMessage> get inbound => _inbound.stream;

  @override
  void send(int type, [dynamic payload, int? contentType]) {
    try {
      log.info(
          "Sending message ${MessageCode.get(type)} with payload $payload to the outer control");
      final _payload = encoding.encode(Payload(contentType, payload));

      postMessage([
        type,
        _payload.header,
        _payload.data,
      ]);
    } catch (e, stack) {
      print(e);
      print(stack);
    }
  }
}

class WebDuplexChannel implements DuplexChannel {
  final Logger log;

  /// The actual WebWorker instance
  final Worker worker;

  @override
  final PayloadHandler encoding;

  final String debugLabel;

  final _inbound = StreamController<DecodedMessage>.broadcast();

  WebDuplexChannel(this.worker, this.encoding, {required this.debugLabel})
      : log = Logger(debugLabel) {
    worker.onMessage.forEach((element) {
      _inbound.add(DecodedMessage.decoded(element.data, encoding));
    });
  }

  @override
  void send(int type, [dynamic payload, int? contentType]) {
    final _payload = encoding.encode(Payload(contentType, payload));
    if (payload != null) {
      log.info(
          "Sending message $type with original:${payload.runtimeType}: encoded as header=${_payload.header} data=${_payload.data}");
      log.info(
          "  > encoded as Sending message $type with payload ${payload.runtimeType}");
    } else {
      log.info("Sending message $type with null payload ${_payload.header}");
    }

    worker.postMessage([
      type,
      _payload.header,
      _payload.data,
    ]);
  }

  @override
  void close() {
    _inbound.close();
    worker.terminate();
  }

  Future get done {
    return _inbound.done;
  }

  @override
  Stream<DecodedMessage> get inbound => _inbound.stream;
}
