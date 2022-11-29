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
  static const messages = [
    MessageCode.supervisor(kInitialize, "command=initialize"),
    MessageCode.grunt(kAck, "received status"),
    MessageCode.grunt(kStart, "command=start"),
    MessageCode.grunt(kStop, "command=stop"),
  ];
}

class GruntMessages {
  static const int kReady = 101;
  static const int kStatusUpdate = 102;
  static const int kError = 103;
  static const messages = [
    MessageCode.grunt(kReady, "ready"),
    MessageCode.grunt(kStatusUpdate, "statusUpdate"),
    MessageCode.grunt(kError, "an error occurred"),
  ];
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

/// A communications channel that lets a supervisor and grunt communicate about
/// work that needs to be completed
class GruntChannel {
  static final log = Logger("gruntChannel");
  final DuplexChannel? boss;
  var _initCount = 0;
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
            print("got from supervisor: ${decodedMessage.messageCodeInfo}");
            if (decodedMessage.payload != null) {
              print("  > payload: ${decodedMessage.payload}");
            }

            if(!_ready.isCompleted) {
              _ready.complete();
            }
            switch (decodedMessage.messageCode) {
              case SupervisorMessages.kInitialize:
                print("  > initialize");

                break;
              case SupervisorMessages.kStart:
                print("  > start");

                grunt!.start(decodedMessage.payload);
                break;
              case SupervisorMessages.kStop:
                print("  > stop");
                grunt!.stop();
                break;
              case SupervisorMessages.kAck:
                print("  > ack");
                break;
              default:
                log.info("Invalid message: ${decodedMessage.messageCodeInfo}");
            }
          } catch (e, stack) {
            print("ERROR!: $e");
            print(stack);
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
      log.info("Sending boss our channel init message: attempt $_initCount");
      boss!.send(GruntMessages.kReady);
      _initCount++;
      await Future.delayed(Duration(milliseconds: 500), startupPing);
    } else {
      log.info("Boss got our ready message");
    }
  }

  void close() {
    _sub?.cancel();
    boss!.close();
    if (!_done.isCompleted) {
      _done.complete();
    }
  }

  Future get done {
    return _done.future;
  }

  void updateStatus(WorkStatus status) {
    boss!.send(GruntMessages.kStatusUpdate, status.toJson(), Payload.kraw);
    if (status.phase == WorkPhase.error || status.phase == WorkPhase.stopped) {
      log.warning("We should be stopped");
      this.close();
    }
  }
}
