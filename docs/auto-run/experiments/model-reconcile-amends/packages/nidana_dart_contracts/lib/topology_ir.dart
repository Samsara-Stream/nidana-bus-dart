/// Stand-in for `package:nidana_dart_contracts/topology_ir.dart`
/// (experiment only): graphs, shell claims, renderers, the JSON form and
/// the analyses of topology-ir@v1.
library;

export 'src/topology_graph.dart'
    show
        GraphRenderer,
        GraphvizRenderer,
        JsonRenderer,
        MermaidRenderer,
        ScopeViolation,
        SelfReference,
        ShellClaim,
        TopicDeclaration,
        TopicNameCollision,
        TopologyCycle,
        TopologyDefinitionGraph,
        TopologyFinding,
        TopologyGraph,
        WriterConflict,
        analyzeTopologyGraph,
        decodeTopologyDefinition,
        decodeTopologyGraph,
        encodeTopologyDefinition,
        encodeTopologyGraph,
        findScopeViolations,
        findSelfReferences,
        findTopicNameCollisions,
        findTopologyCycles,
        findWriterConflicts;
