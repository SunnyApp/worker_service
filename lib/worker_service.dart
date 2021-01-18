library worker_service;

export 'common.dart';
export 'globals.dart';
export 'worker_service_interface.dart'
    if (dart.library.isolate) 'worker_service_isolate.dart'
    if (dart.library.js) 'worker_service_web/worker_service_web.dart';
