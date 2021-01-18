import 'package:worker_service/ports/isolate_entry.dart';
import 'package:worker_service/ports/ports.dart';

Future<WorkIsolate> spawnWorkProxy<T>(IsolateEntry entry, T message,
        {bool errorsAreFatal = true, String debugName}) =>
    throw "Not impl";
