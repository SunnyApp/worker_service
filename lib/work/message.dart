import 'dart:convert';

import 'package:logging/logging.dart';

class DecodedMessage {
  final int? messageCode;
  final dynamic payload;

  DecodedMessage(this.messageCode, [this.payload]);

  factory DecodedMessage.decoded(raw, PayloadHandler env) {
    assert(raw is List, "Payload must be list");
    var l = raw as List;
    assert(l.length == 1 || l.length == 3,
        "Payload must either have 1 or 3 elements but got ${l.length}");
    final messageCode = raw[0] as int?;
    if (l.length > 1) {
      final contentCode = raw[1] as int?;
      final content = raw[2];
      return DecodedMessage(messageCode, env.decode(contentCode, content));
    } else {
      return DecodedMessage(messageCode);
    }
  }

  factory DecodedMessage.raw(raw) {
    assert(raw is List, "Payload must be list");
    var l = raw as List;
    assert(l.length == 1 || l.length == 3,
        "Payload must either have 1 or 3 elements but got ${l.length}");
    final messageCode = raw[0] as int?;
    if (l.length > 1) {
      final content = raw[2];
      return DecodedMessage(messageCode, content);
    } else {
      return DecodedMessage(messageCode);
    }
  }
}

class MessageEnvelope {
  final int messageCode;
  final Payload payload;

  MessageEnvelope(this.messageCode, [Payload payload = Payload.empty])
      : payload = payload;
}

abstract class PayloadHandler {
  dynamic decode(int? contentType, dynamic content);

  Payload encode(Payload payload);

  factory PayloadHandler.of(
          {int? contentType,
          required PayloadDecoder decode,
          required PayloadEncoder encode}) =>
      _PayloadHandler(decode, encode, contentType);

  static const defaults = _PayloadHandler(_decodeJson, _encodeJson, null);
  static const raw = _PayloadHandler(_decodeRaw, _encodeRaw, null);
}

Payload _encodeRaw(Payload payload) => payload;
dynamic _decodeRaw(int? type, payload) => payload;

Payload _encodeJson(Payload payload) {
  if (payload.header == Payload.kraw) {
    return Payload(Payload.kjson, json.encode(payload.data));
  } else {
    return payload;
  }
}

final _log = Logger("json");

dynamic _decodeJson(int? type, inbound) {
  if (inbound is String) {
    return json.decode(inbound);
  } else {
    _log.warning("Expected string but got ${inbound.runtimeType}");
    return inbound;
  }
}

class _PayloadHandler implements PayloadHandler {
  final int? contentType;
  final PayloadDecoder _decode;
  final PayloadEncoder _encode;

  const _PayloadHandler(this._decode, this._encode, this.contentType);

  @override
  Payload encode(Payload env) => _encode(env);

  @override
  dynamic decode(int? contentType, content) {
    return _decode(contentType, content);
  }
}

class Payload {
  static const int kjson = 3;
  static const int kraw = 0;
  static const int kempty = -1;
  static const empty = Payload(kempty, null);
  final int header;
  final dynamic data;

  const Payload(int? header, this.data) : header = header ?? kraw;

  const Payload.raw(this.data) : header = kraw;
}

typedef PayloadEncoder = Payload Function(Payload payload);
typedef PayloadDecoder = dynamic Function(int? contentType, dynamic payload);

dynamic rawPayloadEncoder(MessageEnvelope env) {
  return env.payload.data;
}
