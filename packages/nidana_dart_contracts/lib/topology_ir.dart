/// Topology graphs with their shell claims, the renderers and the JSON form
/// of a graph, and the pure analyses over graphs and definitions.
library;

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
