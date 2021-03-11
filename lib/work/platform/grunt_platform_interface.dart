import 'package:meta/meta.dart';

import '../grunt_channel.dart';
import '../grunt_registry.dart';

///
/// For web, creates a webworker and establishes the bidirectional communication
/// channel:
///
/// * kDebug=true bootstraps the grunt file by executing boostrap_dev.js with a
///   grl parameter that points to the URL of the grunt dart file
/// * kDebug=false loads the full executable javascript file X.grunt.lib.dart.js
Future<DuplexChannel> createGruntChannel(GruntFactory factory,
        {required bool isProduction}) =>
    throw "Not implemented";
DuplexChannel connectToSupervisor(GruntFactory factory) =>
    throw "Not implemented";
