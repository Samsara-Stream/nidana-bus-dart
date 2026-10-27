"""Derive Task 1's renderers.dart from the final draft (Task 2's).

usage: python3 -I variants.py <draft renderers.dart> <out dir>
Task 1 lands MermaidRenderer and the helpers both renderers share; the
GraphvizRenderer keeps nidana.model.5's stub and _graphvizLabel is absent.
Each replacement must apply exactly once.
"""
import sys

GRAPHVIZ_START = "final class GraphvizRenderer implements GraphRenderer {\n"
GRAPHVIZ_STUB = (
    "final class GraphvizRenderer implements GraphRenderer {\n"
    "  const GraphvizRenderer();\n"
    "\n"
    "  @override\n"
    "  String render(TopologyGraph graph) => throw UnimplementedError();\n"
    "}\n"
)
GRAPHVIZ_LABEL_START = "// A Graphviz label: each line escaped"
GRAPHVIZ_LABEL_END = "    .join(r'\\n');\n\n"

src, out = sys.argv[1], sys.argv[2]
text = open(src).read()

# the Graphviz class, from its declaration to the closing brace before _text
start = text.index(GRAPHVIZ_START)
end = text.index("}\n", text.index("  ]);\n", start)) + 2
assert text.count(GRAPHVIZ_START) == 1
t1 = text[:start] + GRAPHVIZ_STUB + text[end:]

# _graphvizLabel and the blank line after it
s = t1.index(GRAPHVIZ_LABEL_START)
e = t1.index(GRAPHVIZ_LABEL_END, s) + len(GRAPHVIZ_LABEL_END)
assert t1.count(GRAPHVIZ_LABEL_START) == 1
t1 = t1[:s] + t1[e:]

open(f"{out}/renderers.t1.dart", "w").write(t1)
print("renderers.t1.dart:", t1.count("\n"), "lines; final:", text.count("\n"), "lines")
