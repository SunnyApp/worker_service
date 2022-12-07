import 'package:uuid/uuid.dart';

const u = Uuid();

String uuid() {
  return u.v4();
}
