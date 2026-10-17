/// Stand-in for `package:nidana_dart_runtime/testing.dart` (experiment
/// only): the part of bus-testing@v1 that the bus-api@v1 bindings
/// forward-reference. Its names are this experiment's assumption, not
/// bus-testing@v1's decision.
library;

export 'src/bus.dart'
    show
        EnvelopeRecorder,
        RecordedEnvelope,
        TestBus,
        VirtualScheduler,
        VirtualSchedulerProvider;
