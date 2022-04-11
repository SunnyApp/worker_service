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
  static final log = Logger("wwDuplexChannel");
  final _inbound = StreamController<DecodedMessage>.broadcast();
  @override
  final PayloadHandler encoding;

  WWDuplexChannel(this.encoding) {
    print("Inside web worker, setting up onmessage listener for supervisor");
    onMessage = allowInterop((event) {
      try {
        if (event is MessageEvent) {
          print("WebWorker received raw message: ${event.data}");
          _inbound.add(DecodedMessage.decoded(event.data, encoding));
          print("Send message to stream...");
        } else {
          print("Got non-message event: $event");
        }
      } catch (e) {
        print("############# ERROR LISTENING TO EVENT #############");
        print(e);
        print("#############                          #############");
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
      log.info("Sending message $type with payload $payload to the outer control");
      final _payload = encoding.encode(Payload(contentType, payload));
      print("Message: $type with payload $payload");
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
  static final log = Logger("webDuplexChannel");

  /// The actual WebWorker instance
  final Worker worker;

  @override
  final PayloadHandler encoding;

  final String debugLabel;

  final _inbound = StreamController<DecodedMessage>.broadcast();

  WebDuplexChannel(this.worker, this.encoding, {required this.debugLabel}) {
    worker.onMessage.forEach((element) {
      _inbound.add(DecodedMessage.decoded(element.data, encoding));
    });
  }

  @override
  void send(int type, [dynamic payload, int? contentType]) {
    log.info("Sending message $type with payload $payload to the other side");
    final _payload = encoding.encode(Payload(contentType, payload));
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
