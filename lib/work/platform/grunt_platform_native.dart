import 'dart:async';
import 'dart:isolate';

import 'package:logging/logging.dart';
import 'package:logging_config/logging_config.dart';

import '../grunt.dart';
import '../grunt_channel.dart';
import '../grunt_registry.dart';
import '../message.dart';

// final _superLog = Logger("supervisor");
final _gruntlog = Logger("grunt");

Future _initializeGrunt(SendPort supervisorSendPort) async {
  configureLogging(LogConfig.root(Level.INFO, handler: LoggingHandler.dev()));
  try {
    var _emitter = StreamController.broadcast();
    var rp = RawReceivePort(_emitter.add);

    /// The first thing we expect back is the grunt function
    var gruntFn = _emitter.stream.first;

    /// Return our port back to the supervisor
    supervisorSendPort.send(rp.sendPort);

    var fn = (await gruntFn as Function);
    var grunt = fn() as Grunt?;
    GruntChannel(
        boss: IsolateDuplexChannel(
            () => _emitter.stream

                /// We skip one item because it's the gruntFn from above
                .skip(1),
            supervisorSendPort),
        grunt: grunt);
  } catch (e, stack) {
    _gruntlog.severe("Grunt blew up! $e", e, stack);
    supervisorSendPort.send([GruntMessages.kError, "$e", Payload.kraw]);
  }
}

Future<DuplexChannel> createGruntChannel(GruntFactory factory,
    {required bool isProduction}) async {
  var _inbound = StreamController.broadcast();
  var port = RawReceivePort(_inbound.add);

  /// First thing is the isolate should return a proper sendPort.  We don't
  /// await this now because it won't actually be sent until after the Isolate
  /// is created.
  var sp = _inbound.stream.first.timeout(const Duration(seconds: 10));
  var isolate = await Isolate.spawn(_initializeGrunt, port.sendPort);
  final gruntPort = await sp as SendPort;
  gruntPort.send(factory.create);
  var dup = IsolateDuplexChannel(() => _inbound.stream, gruntPort, isolate);
  return dup;
}

DuplexChannel connectToSupervisor(GruntFactory factory) {
  /// Is there anything to do?
  throw Exception('Not implemented');
}

final _grunt = Logger("grunt");
final _super = Logger("super");

class IsolateDuplexChannel implements DuplexChannel {
  final Stream Function() _inbound;
  SendPort sendPort;
  final Isolate? isolate;
  final Logger log;
  IsolateDuplexChannel(
    this._inbound,
    this.sendPort, [
    this.isolate,
  ]) : log = isolate == null ? _grunt : _super;

  @override
  void close() {
    isolate?.kill();
  }

  @override
  Stream<DecodedMessage> get inbound =>
      _inbound().map((_) => DecodedMessage.decoded(_, encoding));

  @override
  void send(int type, [dynamic payload, int? contentType]) {
    // log.info("Sending message $type with payload $payload to the other side");
    final _payload = encoding.encode(Payload(contentType, payload));
    try {
      sendPort.send([
        type,
        _payload.header,
        _payload.data,
      ]);
    } catch (e, stack) {
      log.severe("Error sending payload: $e", e, stack);
      rethrow;
    }
  }

  @override
  PayloadHandler get encoding => PayloadHandler.raw;
}
