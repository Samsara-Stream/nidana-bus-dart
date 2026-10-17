/// Stand-in for the main library of `nidana_dart_contracts` (experiment
/// only): topic-model@v1, the app-facing part of topology-dsl@v1, and the
/// placeholder topology-ir@v1 declarations topology-dsl@v1 names.
library;

export 'src/topic_model.dart';
export 'src/topology.dart'
    show
        PipelineValue,
        RawOperator,
        RetryPolicy,
        TopicStream,
        Topology,
        TopologyBuilder,
        TopologyRef,
        topology;
export 'src/topology_ir.dart';
