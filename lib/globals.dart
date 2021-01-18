import 'package:worker_service/common.dart';

String get currentIsolateName => RunnerService.platform.currentIsolateName;
bool get isMainIsolate => RunnerService.platform.isMainIsolate;
