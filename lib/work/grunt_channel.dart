import 'dart:async';

import 'package:logging/logging.dart';

import 'grunt.dart';
import 'grunt_registry.dart';
import 'message.dart';
import 'platform/grunt_platform_interface.dart'
    if (dart.library.io) 'platform/grunt_platform_native.dart'
    if (dart.library.js) 'platform/grunt_platform_web.dart';
import 'work.dart';

class SupervisorMessages {
  /// Establishes the initial communication
  static const int kInitialize = 201;
  static const int kAck = 210;
  static const int kStart = 203;
  static const int kStop = 204;
}

class GruntMessages {
  static const int kReady = 101;
  static const int kStatusUpdate = 102;
  static const int kError = 103;
}

/// Used to communicate work status
abstract class DuplexChannel {
  PayloadHandler get encoding;
  Stream<DecodedMessage> get inbound;

  void send(int type, [dynamic payload, int? contentType]);

  void close();

  static _InMemoryDuplexChannel memory(PayloadHandler encoding) =>
      _InMemoryDuplexChannel(encoding);
}

class MessageEncoding {}

class _InMemoryDuplexChannel implements DuplexChannel {
  final _outboundRaw = StreamController<List>.broadcast();
  final _inbound = StreamController<DecodedMessage>.broadcast();

  @override
  final PayloadHandler encoding;

  _InMemoryDuplexChannel(this.encoding);

  @override
  void close() {
    _inbound.close();
    _outboundRaw.close();
  }

  void connect(_InMemoryDuplexChannel other) {
    _outboundRaw.stream.forEach(
        (m) => other._inbound.add(DecodedMessage.decoded(m, other.encoding)));
    other._outboundRaw.stream
        .forEach((m) => _inbound.add(DecodedMessage.decoded(m, encoding)));
  }

  @override
  Stream<DecodedMessage> get inbound => _inbound.stream;

  @override
  void send(int type, [dynamic payload, int? contentType]) {
    try {
      final _payload = encoding.encode(Payload(contentType, payload));
      _outboundRaw.add([type, _payload.header, _payload.data]);
    } catch (e, stack) {
      print(e);
      print(stack);
    }
  }
}

class GruntChannel {
  static final log = Logger("gruntChannel");
  final DuplexChannel? boss;
  final _done = Completer();
  final _ready = Completer();
  final Grunt? grunt;
  StreamSubscription? _sub;

  factory GruntChannel.create(GruntFactory factory) {
    return GruntChannel(
      boss: connectToSupervisor(factory),
      grunt: factory.create(),
    );
  }

  GruntChannel({
    this.boss,
    this.grunt,
  }) {
    _sub = boss!.inbound.listen(
        (decodedMessage) {
          try {
            print("Got message from boss man!");
            _ready.complete();

            switch (decodedMessage.messageCode) {
              case SupervisorMessages.kInitialize:
                grunt!.initialize(this);
                break;
              case SupervisorMessages.kStart:
                log.info("Got a start message");
                grunt!.start(decodedMessage.payload);
                break;
              case SupervisorMessages.kStop:
                log.info("Got a stop message");
                grunt!.stop();
                break;
              case SupervisorMessages.kAck:
                log.info("Got an ack message!");
                break;
              default:
                log.info("Invalid message: ${decodedMessage.messageCode}");
            }
          } catch (e) {
            log.info("ERROR!: $e");
          }
        },
        cancelOnError: false,
        onDone: () {
          print("Boss stream is done!");
        },
        onError: (err, stac) {
          print("Error with boss $err");
          print(stac);
        });

    startupPing();
    grunt!.initialize(this);
  }

  Future startupPing() async {
    if (!_ready.isCompleted) {
      log.info("Sending boss our channel init message");
      boss!.send(GruntMessages.kReady);
      await Future.delayed(Duration(milliseconds: 500), startupPing);
    } else {
      log.info("Boss got our ready message");
    }
  }

  void close() {
    _sub?.cancel();
    boss!.close();
    _done.complete();
  }

  Future get done {
    return _done.future;
  }

  void updateStatus(WorkStatus status) {
    boss!.send(GruntMessages.kStatusUpdate, status.toJson(), Payload.kjson);
    if (status.phase == WorkPhase.error || status.phase == WorkPhase.stopped) {
      this.close();
    }
  }
}
