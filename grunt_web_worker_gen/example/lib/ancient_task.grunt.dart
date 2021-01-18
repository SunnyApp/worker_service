// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// GruntGenerator
// **************************************************************************

import 'package:logging/logging.dart';
import 'package:logging_config/logging_config.dart';
import 'package:worker_service/common.dart';
import 'package:worker_service/work.dart';
import 'package:grunt_gen_example/ancient_task.dart';

void main() async {
  configureLogging(LogConfig.root(Level.FINE, handler: LoggingHandler.dev()));
  [...RunnerFactory.global.isolateInitializers].forEach((element) {
    print('Running initializer $element');
    element.init(element.param);
  });
  var channel = GruntChannel.create(AncientTask());
  await channel.done;
  print("Job is done");
}
