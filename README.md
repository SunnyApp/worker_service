# isolate_service

[![pub package](https://img.shields.io/pub/v/isolate_service.svg)](https://pub.dartlang.org/packages/isolate_service)
[![Coverage Status](https://coveralls.io/repos/github/SunnyApp/isolate_service/badge.svg?branch=master)](https://coveralls.io/github/SunnyApp/isolate_service?branch=master)

A flutter package that uses the `isolate` package, and adds some convenience for working with isolates in 
Flutter.  Isolates spawned with this library will be automatically destroyed and recreated when using 
hot-restart in Flutter.  This library does not allow the use of Flutter plugins within isolates.  

## Getting Started

You can register initialization globally, so that all isolates spawned using the library will run the 
same initialization
``` dart

// This runs whenever an `IsolateRunner` is spawned - this runs in the spawning isolate, so it accepts
// closures
RunnerFactory.global.onIsolateCreated((IsolateRunner runner) {
    
});

// This registers a function to be run _inside_ the newly spawned isolate
RunnerFactory.global.addIsolateInitializer(_setupLogging, Level.INFO);

_setupLogging(Level info) {
...
}

/// Instead of registering globally, you can create your own custom factory
final customFactory = RunnerFactory()
    ..addIsolateInitializer(_setupLogging, Level.INFO)
    ..onIsolateCreated(...);

```

To spawn an isolate `Runner`, call the `spawn` method on `RunnerFactory`
``` dart

Runner runner = await RunnerFactory.global.spawn((builder) =>  builder
  ..autoclose = true
  ..debugName = "processor"
  ..poolSize = 3
);

```

By default, any spawned `Runner` instances will be automatically closed when the parent `Isolate` 
terminates. 
