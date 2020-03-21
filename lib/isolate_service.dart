library isolate_service;

export 'common.dart';
export 'runner_service_interface.dart'
    if (dart.library.isolate) 'runner_service_isolate.dart'
    if (dart.library.js) 'runner_service_web.dart';
