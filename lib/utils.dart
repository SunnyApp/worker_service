import 'package:uuid/uuid.dart';

final u = Uuid();

String uuid() {
  return u.v4();
}
