import 'package:worker_service/ports/ports.dart';

typedef IsolateEntryFn<T> = void Function(T t);

class IsolateEntry {
  final IsolateEntryFn<SendPort2>? entryFunction;
  final String? entryFileName;

  IsolateEntry({this.entryFunction, this.entryFileName});
}
