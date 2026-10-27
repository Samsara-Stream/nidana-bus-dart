// Appended by run.sh to the committed lib/nidana_dart_contracts.dart: the
// main-library export lines nidana.model.4 adds under the re-plan, the
// declarations of topology-dsl@v2 (Topologies, The builder, The handle,
// Pipeline values) and of topology-ir@v1's The IR and Function references.
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
export 'src/topology_ir.dart'
    show
        CombinatorKind,
        EdgeInput,
        FunctionRef,
        StageInput,
        TopicInput,
        TopologyDefinition,
        TransformEdge;
