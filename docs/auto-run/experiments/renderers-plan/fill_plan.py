"""Fill plan.template.md with the drafted files, verbatim, and write the plan.

usage: python3 -I fill_plan.py <plan.template.md> <draft dir> <out plan.md>
A line '@@FILE path@@' becomes the file at draft/path; '@@T1 renderers@@'
becomes Task 1's renderers.dart, derived by variants.py; '@@BLOCK name@@'
becomes one block of the final renderers.dart (graphviz_class or
graphviz_label). Each block keeps the file's own text, so the plan's code is
the code the dry run ran.
"""
import os
import subprocess
import sys
import tempfile

template, draft, out = sys.argv[1], sys.argv[2], sys.argv[3]
here = os.path.dirname(os.path.abspath(__file__))
final = open(f"{draft}/lib/src/render/renderers.dart").read()

with tempfile.TemporaryDirectory() as tmp:
    subprocess.run(
        [sys.executable, "-I", f"{here}/variants.py",
         f"{draft}/lib/src/render/renderers.dart", tmp],
        check=True, stdout=subprocess.DEVNULL)
    t1 = open(f"{tmp}/renderers.t1.dart").read()


def block(name):
    if name == "graphviz_class":
        start = final.index("final class GraphvizRenderer implements GraphRenderer {\n")
        end = final.index("}\n", final.index("  ]);\n", start)) + 2
        return final[start:end]
    if name == "graphviz_label":
        start = final.index("// A Graphviz label: each line escaped")
        end = final.index("    .join(r'\\n');\n", start) + len("    .join(r'\\n');\n")
        return final[start:end]
    raise SystemExit(f"unknown block {name}")


lines = []
for line in open(template).read().split("\n"):
    s = line.strip()
    if s.startswith("@@FILE ") and s.endswith("@@"):
        lines.append(open(f"{draft}/{s[7:-2]}").read().rstrip("\n"))
    elif s == "@@T1 renderers@@":
        lines.append(t1.rstrip("\n"))
    elif s.startswith("@@BLOCK ") and s.endswith("@@"):
        lines.append(block(s[8:-2]).rstrip("\n"))
    else:
        lines.append(line)
text = "\n".join(lines)
assert "@@" not in text, "an unfilled placeholder"
assert "\u2014" not in text, "an em-dash"
open(out, "w").write(text)
print(f"{out}: {text.count(chr(10)) + 1} lines")
