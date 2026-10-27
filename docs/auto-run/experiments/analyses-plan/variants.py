# variants.py: derives each task's lib/src/analysis/analyses.dart from
# draft/analyses.src.dart, whose chunks carry a "//@ N" line naming the task
# that writes them, and the stubs of HEAD's analyses.dart.
#   python3 -I variants.py <draft/analyses.src.dart> <HEAD analyses.dart> <out dir>
# writes <out>/analyses.t1.dart to analyses.t3.dart (the stubs of later tasks
# kept as HEAD has them) and <out>/analyses.dart (every chunk, markers gone).
import re
import sys

src_path, head_path, out = sys.argv[1:4]
src = open(src_path).read()
head = open(head_path).read()

# The draft's chunks: (task, text), in order. A chunk runs from its marker to
# the next marker; imports are one-line chunks.
chunks = []
parts =re.split(r"^//@ (\d+)\n", src, flags=re.M)
assert parts[0] == "", "the draft starts with a marker"
for i in range(1, len(parts), 2):
    chunks.append((int(parts[i]), parts[i + 1]))

# HEAD's stubs, by function name, each with the dartdoc above it.
stubs = {}
body = head[head.index("\n\n") + 2 :]
for m in re.finditer(r"((?:///.*\n)*)(List<\w+> (\w+)\((?:.|\n)*?throw UnimplementedError\(\);\n)", body):
    stubs[m.group(3)] = m.group(1) + m.group(2)
assert len(stubs) == 6, sorted(stubs)

public = {
    "findTopologyCycles": 1,
    "findSelfReferences": 2,
    "findWriterConflicts": 3,
    "findScopeViolations": 3,
    "analyzeTopologyGraph": 4,
    "findTopicNameCollisions": 4,
}


def chunk_name(text):
    m = re.search(r"^List<\w+> (\w+)\(", text, flags=re.M)
    return m.group(1) if m else None


def build(task):
    imports = [t for (n, t) in chunks if t.startswith("import ") and n <= task]
    rest = []
    for n, text in chunks:
        if text.startswith("import "):
            continue
        name = chunk_name(text)
        if n <= task:
            rest.append(text.rstrip("\n") + "\n")
        elif name in public:
            rest.append(stubs[name])
    return "".join(i.rstrip("\n") + "\n" for i in imports) + "\n" + "\n".join(rest)


for task in (1, 2, 3):
    open(f"{out}/analyses.t{task}.dart", "w").write(build(task))
open(f"{out}/analyses.dart", "w").write(build(4))
print("variants written:", ", ".join(f"t{t}" for t in (1, 2, 3)), "and the final")
