import 'dart:async';

import 'package:collection/collection.dart' show IterableExtension;
import 'package:logging/logging.dart';

import '../utils.dart';
import 'grunt_channel.dart';
import 'grunt_registry.dart';
import 'message.dart';
import 'work.dart';

WorkPhase? workPhaseOf(int? i) {
  return WorkPhase.values.firstWhereOrNull((element) => element.ordinal == i);
}

class ErrorStack {
  final Object? error;
  final StackTrace? stack;

  ErrorStack(this.error, [this.stack]);

  const ErrorStack.of({
    required this.error,
    required this.stack,
  });

  static ErrorStack? fromJson(map) {
    if (map == null) return null;
    return ErrorStack.of(
      error: map['error']?.toString(),
      stack: StackTrace.fromString(map['stack']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'error': this.error?.toString(),
      'stack': this.stack?.toString(),
    };
  }
}

/// This is the implementation class that processes a long-running task
abstract class Grunt {
  /// A unique key that identifies this worker
  String get key;

  /// The specific job that this grunt is processing currently
  String get jobId;

  GruntChannel get channel;

  WorkStatus get currentStatus;

  WorkPhase get workPhase;

  Logger get log;

  set workPhase(WorkPhase phase);

  /// Initializes and creates a job id
  FutureOr initialize(GruntChannel channel);

  /// Instructs the agent to start processing
  FutureOr start(dynamic params);

  /// Instructs the agent to stop
  FutureOr stop();
}

extension GruntExt on Grunt {
  bool get isShuttingDown {
    return this.workPhase == WorkPhase.stopping;
  }

  void sendStatus() {
    this.channel.updateStatus(this.currentStatus);
  }

  bool withPhase(WorkPhase phase, FutureOr exec()) {
    if (this.workPhase < phase) {
      log.info("Advancing phase: $phase: we are ${this.currentStatus.phase}");
      this.workPhase = phase;
      this.sendStatus();
      exec();
      return true;
    } else {
      log.info("Wrong phase: $phase but we were ${this.currentStatus.phase}");
      return false;
    }
  }
}

mixin GruntMixin<SELF extends Grunt> implements Grunt, GruntFactory<SELF> {
  PayloadHandler get fallbackEncoding => PayloadHandler.defaults;

  PayloadHandler? _encoding;

  GruntChannel? _channel;
  Logger? _log;

  @override
  Logger get log => _log ??= Logger("$runtimeType");

  @override
  final String jobId = uuid();

  @override
  WorkPhase workPhase = WorkPhase.ready;

  double? total;
  double progress = 0.0;

  dynamic params;
  ErrorStack? error;

  String? message;
  Map<String, dynamic>? state;

  @override
  void initialize(GruntChannel channel, [params]) {
    this._channel = channel;
    this.withPhase(WorkPhase.initializing, () {
      /// Nothing to do?
      doInitialize();
    });
  }

  FutureOr doInitialize() {}

  Future execute(dynamic params);

  FutureOr onError(ErrorStack? err) {}

  FutureOr onStop() {}

  @override
  PayloadHandler get encoding {
    final _fb = this.fallbackEncoding;
    return _encoding ??= PayloadHandler.of(decode: (type, content) {
      return decodePayload(type, content, _fb.decode);
    }, encode: (envelope) {
      return encodePayload(envelope, _fb.encode);
    });
  }

  /// Override this to customize encoding strategy.  Call next to chain them together,
  /// or just return something custom
  Payload encodePayload(Payload payload, PayloadEncoder next) {
    return next(payload);
  }

  dynamic decodePayload(
      int? contentType, dynamic content, PayloadDecoder next) {
    return next(contentType, content);
  }

  @override
  Future start(dynamic params) async {
    this.withPhase(WorkPhase.starting, () async {
      try {
        this.params = params;
        workPhase = WorkPhase.processing;
        sendStatus();

        await execute(params);
        progress = 100.0;
        workPhase = WorkPhase.stopped;
        sendStatus();
      } catch (e, stack) {
        log.severe("Error uploading file: $e", e, stack);
        error = ErrorStack(e, stack);
        workPhase = WorkPhase.stopping;
        sendStatus();

        await onError(this.error);
        workPhase = WorkPhase.error;
        sendStatus();
      }
    });
  }

  void sendUpdate(
      {String? message, double? progress, Map<String, dynamic>? state}) {
    if (message != null) {
      this.message = message;
    }
    if (progress != null) {
      this.progress = progress;
    }
    if (state != null) {
      this.state = state;
    }

    sendStatus();
  }

  @override
  void stop() {
    workPhase = WorkPhase.stopping;
    sendStatus();
    onStop();
  }

  @override
  WorkStatus get currentStatus {
    return WorkStatus(
      jobId: jobId,
      phase: workPhase,
      message: message,
      error: error?.error?.toString(),
      errorStack: error?.stack?.toString(),
      more: state,
      total: total,
      percentComplete: progress,
    );
  }

  @override
  GruntChannel get channel =>
      _channel ??
      (throw Exception(
          "Attempting to communicate before channel has been established"));
}
