/// Topology graphs with their shell claims, the renderers and the JSON form
/// of a graph, and the pure analyses over graphs and definitions.
library;

export 'src/analysis/analyses.dart'
    show
        analyzeTopologyGraph,
        findScopeViolations,
        findSelfReferences,
        findTopicNameCollisions,
        findTopologyCycles,
        findWriterConflicts;
export 'src/analysis/findings.dart'
    show
        ScopeViolation,
        SelfReference,
        TopicDeclaration,
        TopicNameCollision,
        TopologyCycle,
        TopologyFinding,
        WriterConflict;
export 'src/graph/graph.dart'
    show GraphRenderer, ShellClaim, TopologyDefinitionGraph, TopologyGraph;
export 'src/json/codec.dart'
    show
        JsonRenderer,
        decodeTopologyDefinition,
        decodeTopologyGraph,
        encodeTopologyDefinition,
        encodeTopologyGraph;
export 'src/render/renderers.dart' show GraphvizRenderer, MermaidRenderer;
