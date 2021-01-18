// ignore_for_file: slash_for_doc_comments
// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/**
 * Concurrent programming using _isolates_:
 * independent workers that are similar to threads
 * but don't share memory,
 * communicating only via messages.
 *
 * To use this library in your code:
 *
 *     import 'dart:isolate';
 *
 * {@category VM}
 */

// import "dart:_internal" show Since;
import "dart:async";
import "dart:typed_data" show ByteBuffer, TypedData, Uint8List;

part "capability.dart";

/**
 * Thrown when an isolate cannot be created.
 */
class IsolateSpawnException2 implements Exception {
  /** Error message reported by the spawn operation. */
  final String message;
  @pragma("vm:entry-point")
  IsolateSpawnException2(this.message);
  @override
  String toString() => "IsolateSpawnException: $message";
}

/**
 * An isolated Dart execution context.
 *
 * All Dart code runs in an isolate, and code can access classes and values
 * only from the same isolate. Different isolates can communicate by sending
 * values through ports (see [ReceivePort2], [SendPort2]).
 *
 * An `Isolate` object is a reference to an isolate, usually different from
 * the current isolate.
 * It represents, and can be used to control, the other isolate.
 *
 * When spawning a new isolate, the spawning isolate receives an `Isolate`
 * object representing the new isolate when the spawn operation succeeds.
 *
 * Isolates run code in its own event loop, and each event may run smaller tasks
 * in a nested microtask queue.
 *
 * An `Isolate` object allows other isolates to control the event loop
 * of the isolate that it represents, and to inspect the isolate,
 * for example by pausing the isolate or by getting events when the isolate
 * has an uncaught error.
 *
 * The [controlPort] identifies and gives access to controlling the isolate,
 * and the [pauseCapability] and [terminateCapability] guard access
 * to some control operations.
 * For example, calling [pause] on an `Isolate` object created without a
 * [pauseCapability], has no effect.
 *
 * The `Isolate` object provided by a spawn operation will have the
 * control port and capabilities needed to control the isolate.
 * New isolate objects can be created without some of these capabilities
 * if necessary, using the [WorkIsolate.Isolate] constructor.
 *
 * An `Isolate` object cannot be sent over a `SendPort`, but the control port
 * and capabilities can be sent, and can be used to create a new functioning
 * `Isolate` object in the receiving port's isolate.
 */
abstract class WorkIsolate<P extends SendPort2> {
  /** Argument to `ping` and `kill`: Ask for immediate action. */
  static const int immediate = 0;
  /** Argument to `ping` and `kill`: Ask for action before the next event. */
  static const int beforeNextEvent = 1;

  /**
   * Control port used to send control messages to the isolate.
   *
   * The control port identifies the isolate.
   *
   * An `Isolate` object allows sending control messages
   * through the control port.
   *
   * Some control messages require a specific capability to be passed along
   * with the message (see [pauseCapability] and [terminateCapability]),
   * otherwise the message is ignored by the isolate.
   */
  final SendPort2 controlPort;

  /// Capability granting the ability to pause the isolate.
  ///
  /// This capability is required by [pause].
  /// If the capability is `null`, or if it is not the correct pause capability
  /// of the isolate identified by [controlPort],
  /// then calls to [pause] will have no effect.
  ///
  /// If the isolate is spawned in a paused state, use this capability as
  /// argument to the [resume] method in order to resume the paused isolate.
  final Capability2 pauseCapability;

  /// Capability granting the ability to terminate the isolate.
  ///
  /// This capability is required by [kill] and [setErrorsFatal].
  /// If the capability is `null`, or if it is not the correct termination
  /// capability of the isolate identified by [controlPort],
  /// then calls to those methods will have no effect.
  final Capability2 terminateCapability;

  /// The name of the [WorkIsolate] displayed for debug purposes.
  ///
  /// This can be set using the `debugName` parameter in [spawn] and [spawnUri].
  ///
  /// This name does not uniquely identify an isolate. Multiple isolates in the
  /// same process may have the same `debugName`.
  ///
  /// For a given isolate, this value will be the same as the values returned by
  /// `Dart_DebugName` in the C embedding API and the `debugName` property in
  /// [IsolateMirror].
  String get debugName;

  WorkIsolate(this.controlPort,
      {this.pauseCapability, this.terminateCapability});

  /// Requests the isolate to pause.
  ///
  /// When the isolate receives the pause command, it stops
  /// processing events from the event loop queue.
  /// It may still add new events to the queue in response to, e.g., timers
  /// or receive-port messages. When the isolate is resumed,
  /// it starts handling the already enqueued events.
  ///
  /// The pause request is sent through the isolate's command port,
  /// which bypasses the receiving isolate's event loop.
  /// The pause takes effect when it is received, pausing the event loop
  /// as it is at that time.
  ///
  /// The [resumeCapability] is used to identity the pause,
  /// and must be used again to end the pause using [resume].
  /// If [resumeCapability] is omitted, a new capability object is created
  /// and used instead.
  ///
  /// If an isolate is paused more than once using the same capability,
  /// only one resume with that capability is needed to end the pause.
  ///
  /// If an isolate is paused using more than one capability,
  /// each pause must be individually ended before the isolate resumes.
  ///
  /// Returns the capability that must be used to end the pause.
  /// This is either [resumeCapability], or a new capability when
  /// [resumeCapability] is omitted.
  ///
  /// If [pauseCapability] is `null`, or it's not the pause capability
  /// of the isolate identified by [controlPort],
  /// the pause request is ignored by the receiving isolate.
  Capability2 pause([Capability2 resumeCapability]) {
    resumeCapability ??= Capability2();
    _pause(resumeCapability);
    return resumeCapability;
  }

  /** Internal implementation of [pause]. */
  external void _pause(Capability2 resumeCapability);

  /**
   * Resumes a paused isolate.
   *
   * Sends a message to an isolate requesting that it ends a pause
   * that was previously requested.
   *
   * When all active pause requests have been cancelled, the isolate
   * will continue processing events and handling normal messages.
   *
   * If the [resumeCapability] is not one that has previously been used
   * to pause the isolate, or it has already been used to resume from
   * that pause, the resume call has no effect.
   */
  external void resume(Capability2 resumeCapability);

  void sendToIsolate(Object message) {
    controlPort.send(message);
  }

  /// Requests an exit message on [responsePort] when the isolate terminates.
  ///
  /// The isolate will send [response] as a message on [responsePort] as the last
  /// thing before it terminates. It will run no further code after the message
  /// has been sent.
  ///
  /// Adding the same port more than once will only cause it to receive one exit
  /// message, using the last response value that was added,
  /// and it only needs to be removed once using [removeOnExitListener].
  ///
  /// If the isolate has terminated before it can receive this request,
  /// no exit message will be sent.
  ///
  /// The [response] object must follow the same restrictions as enforced by
  /// [SendPort2.send].
  /// It is recommended to only use simple values that can be sent to all
  /// isolates, like `null`, booleans, numbers or strings.
  ///
  /// Since isolates run concurrently, it's possible for it to exit before the
  /// exit listener is established, and in that case no response will be
  /// sent on [responsePort].
  /// To avoid this, either use the corresponding parameter to the spawn
  /// function, or start the isolate paused, add the listener and
  /// then resume the isolate.
  /* TODO(lrn): Can we do better? Can the system recognize this message and
   * send a reply if the receiving isolate is dead?
   */
  external void addOnExitListener(SendPort2 responsePort, {Object response});

  /// Stops listening for exit messages from the isolate.
  ///
  /// Requests for the isolate to not send exit messages on [responsePort].
  /// If the isolate isn't expecting to send exit messages on [responsePort],
  /// because the port hasn't been added using [addOnExitListener],
  /// or because it has already been removed, the request is ignored.
  ///
  /// If the same port has been passed via [addOnExitListener] more than once,
  /// only one call to `removeOnExitListener` is needed to stop it from receiving
  /// exit messages.
  ///
  /// Closing the receive port that is associated with the [responsePort] does
  /// not stop the isolate from sending uncaught errors, they are just going to
  /// be lost.
  ///
  /// An exit message may still be sent if the isolate terminates
  /// before this request is received and processed.
  external void removeOnExitListener(SendPort2 responsePort);

  /**
   * Sets whether uncaught errors will terminate the isolate.
   *
   * If errors are fatal, any uncaught error will terminate the isolate
   * event loop and shut down the isolate.
   *
   * This call requires the [terminateCapability] for the isolate.
   * If the capability is absent or incorrect, no change is made.
   *
   * Since isolates run concurrently, it's possible for the receiving isolate
   * to exit due to an error, before a request, using this method, has been
   * received and processed.
   * To avoid this, either use the corresponding parameter to the spawn
   * function, or start the isolate paused, set errors non-fatal and
   * then resume the isolate.
   */
  external void setErrorsFatal(bool errorsAreFatal);

  /**
   * Requests the isolate to shut down.
   *
   * The isolate is requested to terminate itself.
   * The [priority] argument specifies when this must happen.
   *
   * The [priority], when provided, must be one of [immediate] or
   * [beforeNextEvent] (the default).
   * The shutdown is performed at different times depending on the priority:
   *
   * * `immediate`: The isolate shuts down as soon as possible.
   *     Control messages are handled in order, so all previously sent control
   *     events from this isolate will all have been processed.
   *     The shutdown should happen no later than if sent with
   *     `beforeNextEvent`.
   *     It may happen earlier if the system has a way to shut down cleanly

   *     at an earlier time, even during the execution of another event.
   * * `beforeNextEvent`: The shutdown is scheduled for the next time
   *     control returns to the event loop of the receiving isolate,
   *     after the current event, and any already scheduled control events,
   *     are completed.
   *
   * If [terminateCapability] is `null`, or it's not the terminate capability
   * of the isolate identified by [controlPort],
   * the kill request is ignored by the receiving isolate.
   */
  external void kill({int priority = beforeNextEvent});

  /// Requests that the isolate send [response] on the [responsePort].
  ///
  /// The [response] object must follow the same restrictions as enforced by
  /// [SendPort2.send].
  /// It is recommended to only use simple values that can be sent to all
  /// isolates, like `null`, booleans, numbers or strings.
  ///
  /// If the isolate is alive, it will eventually send `response`
  /// (defaulting to `null`) on the response port.
  ///
  /// The [priority] must be one of [immediate] or [beforeNextEvent].
  /// The response is sent at different times depending on the ping type:
  ///
  /// * `immediate`: The isolate responds as soon as it receives the
  ///     control message. This is after any previous control message
  ///     from the same isolate has been received and processed,
  ///     but may be during execution of another event.
  /// * `beforeNextEvent`: The response is scheduled for the next time
  ///     control returns to the event loop of the receiving isolate,
  ///     after the current event, and any already scheduled control events,
  ///     are completed.
  external void ping(SendPort2 responsePort,
      {Object response, int priority = immediate});

  /**
   * Requests that uncaught errors of the isolate are sent back to [port].
   *
   * The errors are sent back as two elements lists.
   * The first element is a `String` representation of the error, usually
   * created by calling `toString` on the error.
   * The second element is a `String` representation of an accompanying
   * stack trace, or `null` if no stack trace was provided.
   * To convert this back to a [StackTrace] object, use [StackTrace.fromString].
   *
   * Listening using the same port more than once does nothing.
   * A port will only receive each error once,
   * and will only need to be removed once using [removeErrorListener].

   * Closing the receive port that is associated with the port does not stop
   * the isolate from sending uncaught errors, they are just going to be lost.
   * Instead use [removeErrorListener] to stop receiving errors on [port].
   *
   * Since isolates run concurrently, it's possible for it to exit before the
   * error listener is established. To avoid this, start the isolate paused,
   * add the listener and then resume the isolate.
   */
  external void addErrorListener(SendPort2 port);

  /**
   * Stops listening for uncaught errors from the isolate.
   *
   * Requests for the isolate to not send uncaught errors on [port].
   * If the isolate isn't expecting to send uncaught errors on [port],
   * because the port hasn't been added using [addErrorListener],
   * or because it has already been removed, the request is ignored.
   *
   * If the same port has been passed via [addErrorListener] more than once,
   * only one call to `removeErrorListener` is needed to stop it from receiving
   * uncaught errors.
   *
   * Uncaught errors message may still be sent by the isolate
   * until this request is received and processed.
   */
  external void removeErrorListener(SendPort2 port);

  /**
   * Returns a broadcast stream of uncaught errors from the isolate.
   *
   * Each error is provided as an error event on the stream.
   *
   * The actual error object and stackTraces will not necessarily
   * be the same object types as in the actual isolate, but they will
   * always have the same [Object.toString] result.
   *
   * This stream is based on [addErrorListener] and [removeErrorListener].
   */
  Stream get messages;
}

/**
 * Sends messages to its [ReceivePort2]s.
 *
 * [SendPort2]s are created from [ReceivePort2]s. Any message sent through
 * a [SendPort2] is delivered to its corresponding [ReceivePort2]. There might be
 * many [SendPort2]s for the same [ReceivePort2].
 *
 * [SendPort2]s can be transmitted to other isolates, and they preserve equality
 * when sent.
 */
abstract class SendPort2 implements Capability2 {
  /**
   * Sends an asynchronous [message] through this send port, to its
   * corresponding `ReceivePort`.
   *
   * The content of [message] can be: primitive values (null, num, bool, double,
   * String), instances of [SendPort2], and lists and maps whose elements are any
   * of these. List and maps are also allowed to be cyclic.
   *
   * In the special circumstances when two isolates share the same code and are
   * running in the same process (e.g. isolates created via [WorkIsolate.spawn]), it
   * is also possible to send object instances (which would be copied in the
   * process). This is currently only supported by the
   * [Dart Native](https://dart.dev/platforms#dart-native-vm-jit-and-aot)
   * platform.
   *
   * The send happens immediately and doesn't block.  The corresponding receive
   * port can receive the message as soon as its isolate's event loop is ready
   * to deliver it, independently of what the sending isolate is doing.
   */
  void send(Object message);

  /**
   * Tests whether [other] is a [SendPort2] pointing to the same
   * [ReceivePort2] as this one.
   */
  @override
  bool operator ==(var other);

  /**
   * Returns an immutable hash code for this send port that is
   * consistent with the == operator.
   */
  @override
  int get hashCode;
}

/**
 * Together with [SendPort2], the only means of communication between isolates.
 *
 * [ReceivePort2]s have a `sendPort` getter which returns a [SendPort2].
 * Any message that is sent through this [SendPort2]
 * is delivered to the [ReceivePort2] it has been created from. There, the
 * message is dispatched to the `ReceivePort`'s listener.
 *
 * A [ReceivePort2] is a non-broadcast stream. This means that it buffers
 * incoming messages until a listener is registered. Only one listener can
 * receive messages. See [Stream.asBroadcastStream] for transforming the port
 * to a broadcast stream.
 *
 * A [ReceivePort2] may have many [SendPort2]s.
 */
abstract class ReceivePort2 implements Stream<dynamic> {
  /**
   * Opens a long-lived port for receiving messages.
   *
   * A [ReceivePort2] is a non-broadcast stream. This means that it buffers
   * incoming messages until a listener is registered. Only one listener can
   * receive messages. See [Stream.asBroadcastStream] for transforming the port
   * to a broadcast stream.
   *
   * A receive port is closed by canceling its subscription.
   */
  external factory ReceivePort2();

  /**
   * Creates a [ReceivePort2] from a [RawReceivePort2].
   *
   * The handler of the given [rawPort] is overwritten during the construction
   * of the result.
   */
  external factory ReceivePort2.fromRawReceivePort(RawReceivePort2 rawPort);

  /**
   * Inherited from [Stream].
   *
   * Note that [onError] and [cancelOnError] are ignored since a ReceivePort
   * will never receive an error.
   *
   * The [onDone] handler will be called when the stream closes.
   * The stream closes when [close] is called.
   */
  @override
  StreamSubscription<dynamic> listen(void onData(var message),
      {Function onError, void onDone(), bool cancelOnError});

  /**
   * Closes `this`.
   *
   * If the stream has not been canceled yet, adds a close-event to the event
   * queue and discards any further incoming messages.
   *
   * If the stream has already been canceled this method has no effect.
   */
  void close();

  /**
   * Returns a [SendPort2] that sends to this receive port.
   */
  SendPort2 get sendPort;
}

abstract class RawReceivePort2 {
  /**
   * Opens a long-lived port for receiving messages.
   *
   * A [RawReceivePort2] is low level and does not work with [Zone]s. It
   * can not be paused. The data-handler must be set before the first
   * event is received.
   */
  external factory RawReceivePort2([Function handler]);

  /**
   * Sets the handler that is invoked for every incoming message.
   *
   * The handler is invoked in the root-zone ([Zone.root]).
   */
  void set handler(Function newHandler);

  /**
   * Closes the port.
   *
   * After a call to this method any incoming message is silently dropped.
   */
  void close();

  /**
   * Returns a [SendPort2] that sends to this raw receive port.
   */
  SendPort2 get sendPort;
}

/**
 * Description of an error from another isolate.
 *
 * This error has the same `toString()` and `stackTrace.toString()` behavior
 * as the original error, but has no other features of the original error.
 */
class RemoteError2 implements Error {
  final String _description;

  @override
  final StackTrace stackTrace;

  RemoteError2(String description, String stackDescription)
      : _description = description,
        stackTrace = StackTrace.fromString(stackDescription);

  @override
  String toString() => _description;
}

/**
 * An efficiently transferable sequence of byte values.
 *
 * A [TransferableTypedData2] is created from a number of bytes.
 * This will take time proportional to the number of bytes.
 *
 * The [TransferableTypedData2] can be moved between isolates, so
 * sending it through a send port will only take constant time.
 *
 * When sent this way, the local transferable can no longer be materialized,
 * and the received object is now the only way to materialize the data.
 */

abstract class TransferableTypedData2 {
  /**
   * Creates a new [TransferableTypedData2] containing the bytes of [list].
   *
   * It must be possible to create a single [Uint8List] containing the
   * bytes, so if there are more bytes than what the platform allows in
   * a single [Uint8List], then creation fails.
   */
  external factory TransferableTypedData2.fromList(List<TypedData> list);

  /**
   * Creates a new [ByteBuffer] containing the bytes stored in this [TransferableTypedData2].
   *
   * The [TransferableTypedData2] is a cross-isolate single-use resource.
   * This method must not be called more than once on the same underlying
   * transferable bytes, even if the calls occur in different isolates.
   */
  ByteBuffer materialize();
}
