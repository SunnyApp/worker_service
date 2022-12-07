import 'package:equatable/equatable.dart';

import 'grunt.dart';

enum WorkPhase {
  ready,
  initializing,
  starting,
  processing,
  stopping,
  stopped,
  error
}

extension WorkPhaseVerify on WorkPhase? {
  bool verify(Grunt job) {
    return job.workPhase == this;
  }

  bool operator >(WorkPhase a) {
    return this!.ordinal > a.ordinal;
  }

  bool operator <(WorkPhase a) {
    return this!.ordinal < a.ordinal;
  }

  bool operator >=(WorkPhase a) {
    return this!.ordinal >= a.ordinal;
  }

  bool operator <=(WorkPhase a) {
    return this!.ordinal <= a.ordinal;
  }

  bool get isStopped {
    return this == WorkPhase.stopped || this == WorkPhase.error;
  }

  bool get isNotStopped {
    return isStopped != true;
  }

  int get ordinal {
    switch (this) {
      case WorkPhase.ready:
        return 0;
      case WorkPhase.initializing:
        return 1;
      case WorkPhase.starting:
        return 2;
      case WorkPhase.processing:
        return 3;
      case WorkPhase.stopping:
        return 4;
      case WorkPhase.stopped:
        return 5;
      case WorkPhase.error:
        return 6;
      default:
        return -1;
    }
  }
}

class WorkStatus extends Equatable {
  final String? jobId;
  final WorkPhase? phase;
  final String? message;
  final String? error;
  final String? errorStack;
  final double? completed;
  final double? total;
  final double? percentComplete;
  final Map<String, dynamic>? more;

  const WorkStatus(
      {this.phase,
      required this.jobId,
      this.message,
      this.more,
      this.error,
      this.errorStack,
      this.percentComplete,
      this.completed,
      this.total});

  @override
  List<Object?> get props {
    return [jobId, phase, more, message, completed, total, percentComplete];
  }

  WorkStatus operator +(WorkStatus other) {
    return this.copyWith(
      phase: other.phase,
      jobId: other.jobId,
      message: other.message,
      error: other.error,
      errorStack: other.errorStack,
      completed: other.completed,
      total: other.total,
      percentComplete: other.percentComplete,
      more: other.more,
    );
  }

  WorkStatus copyWith({
    WorkPhase? phase,
    String? jobId,
    String? message,
    Object? error,
    String? errorStack,
    double? completed,
    double? total,
    double? percentComplete,
    Map<String, dynamic>? more,
  }) {
    return WorkStatus(
      jobId: jobId ?? this.jobId,
      phase: phase ?? this.phase,
      message: message ?? this.message,
      error: error?.toString() ?? this.error,
      errorStack: errorStack ?? this.errorStack,
      completed: completed ?? this.completed,
      total: total ?? this.total,
      percentComplete: percentComplete ?? this.percentComplete,
      more: more ?? this.more,
    );
  }

  static WorkStatus? fromJson(json) {
    if (json == null) return null;
    return WorkStatus(
      jobId: json['jobId'] as String?,
      phase: workPhaseOf(json['phase'] as int?),
      message: json['message'] as String?,
      error: json['error']?.toString(),
      errorStack: json['errorStack'] as String?,
      more: json['more'] as Map<String, dynamic>?,
      completed: json['completed'] as double?,
      percentComplete: json['percentComplete'] as double?,
      total: json['total'] as double?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'jobId': this.jobId,
      'phase': this.phase.ordinal,
      'message': this.message,
      'completed': this.completed,
      'error': this.error,
      'errorStack': this.errorStack,
      'more': this.more,
      'percentComplete': this.percentComplete,
      'total': this.total,
    };
  }

  const WorkStatus.ready()
      : percentComplete = 0,
        total = null,
        jobId = null,
        more = null,
        error = null,
        errorStack = null,
        phase = WorkPhase.ready,
        message = null,
        completed = 0;
}

class Work {
  final String? jobId;

  Work({this.jobId});
}

typedef ChannelSender = void Function(int code, dynamic payload);
