import 'dart:async';

import 'package:sunny_dart/extensions.dart';
import 'package:sunny_dart/helpers.dart';

import 'grunt.dart';
import 'grunt_channel.dart';
import 'grunt_registry.dart';
import 'message.dart';
import 'platform/grunt_platform_interface.dart'
    if (dart.library.io) 'platform/grunt_platform_native.dart'
    if (dart.library.js) 'platform/grunt_platform_web.dart';
import 'work.dart';

class Supervisor<G extends Grunt> with LoggingMixin {
  /// This is how we send and receive messages to/from the worker
  final DuplexChannel grunt;

  final Type gruntType;

  /// The last status reported by the worker
  WorkStatus _status = const WorkStatus.ready();
  final _ready = SafeCompleter();

  StreamSubscription? _sub;
  final _ctrl = StreamController<WorkStatus>.broadcast();

  static Future<Supervisor> create<G extends Grunt>(GruntFactory<G> entry,
      {bool debug = false, required bool isProduction}) async {
    return debug == true
        ? Supervisor.debug(entry)
        : Supervisor(
            gruntType: G,
            grunt: await createGruntChannel(entry, isProduction: isProduction));
  }

  factory Supervisor.debug(GruntFactory<G> fn) {
    final spv = DuplexChannel.memory(fn.encoding);
    final grnt = DuplexChannel.memory(fn.encoding);
    spv.connect(grnt);
    var supervisor = Supervisor<G>(gruntType: G, grunt: spv);
    final grunt = fn.create();
    GruntChannel(boss: grnt, grunt: grunt);
    return supervisor;
  }

  Supervisor({required this.gruntType, required this.grunt}) {
    _sub = grunt.inbound.listen((DecodedMessage event) {
      log.info("Supervisor got update: ${event.messageCode}");
      switch (event.messageCode) {
        case GruntMessages.kReady:
          log.info("Got ready message!");
          _ready.complete();
          grunt.send(SupervisorMessages.kAck);
          break;
        case GruntMessages.kStatusUpdate:
          if (!_ready.isCompleted) {
            _ready.complete();
          }
          var workStatus = WorkStatus.fromJson(event.payload);
          if (workStatus != null) {
            _status = _status + workStatus;
            _ctrl.add(_status);
          }
          break;
        default:
          log.severe("Invalid message: ${event.messageCode}");
      }
    });
  }

  WorkStatus get status => _status;

  String? get jobId => status.jobId;

  Future waitFor(WorkPhase t,
      {Duration? timeout, FutureOr<WorkStatus> onTimeout()?}) async {
    try {
      if (_status.phase < t) {
        log.warning(
            'We are still in ${_status.phase} phase - waiting for $t${timeout == null ? '' : ' (timeout ${timeout.inMilliseconds}'}');
        return _ctrl.stream
            .firstWhere((element) => element.phase >= t)
            .maybeTimeout(timeout, onTimeout!);
      } else {
        log.warning(
            'We are at ${_status.phase} phase - good enough to move on to for $t');
        return;
      }
    } on TimeoutException {
      log.severe("timed out after $timeout waiting for $t");
      rethrow;
    }
  }

  Future start({params, Duration? timeout}) async {
    await waitFor(WorkPhase.initializing, timeout: timeout);
    grunt.send(SupervisorMessages.kStart, params);
  }

  Future stop() async {
    grunt.send(SupervisorMessages.kStop);
    return waitFor(WorkPhase.stopped);
  }

  Future close() async {
    await stop();
    grunt.close();
    await _sub?.cancel();
    await _ctrl.close();
  }

  Stream<WorkStatus> get onStatus => _ctrl.stream;
}
