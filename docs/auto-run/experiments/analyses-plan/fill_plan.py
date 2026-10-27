# fill_plan.py: writes docs/superpowers/plans/nidana.model.12.md from
# plan.template.md, filling @@CONSTRAINTS@@ with the derivative's Global
# Constraints 1 to 8 as written, each @@FILE path@@ with draft/<path>, and
# @@COMPONENTS@@ with _components as variants.py's final analyses.dart holds
# it, so the plan's code is exactly what run.sh ran.
#   python3 -I fill_plan.py <repo root> <final analyses.dart>
import re
import sys

root, final = sys.argv[1:3]
here = root + "/docs/auto-run/experiments/analyses-plan/"
s = open(here + "plan.template.md").read()
der = open(root + "/hsdd-context/superpowers/nidana.model.12.md").read().split("\n")
start = next(i for i, l in enumerate(der) if l.startswith("1. Every plan task"))
end = next(i for i, l in enumerate(der) if l.startswith("8. Review tier"))
s = s.replace("@@CONSTRAINTS@@", "\n".join(der[start : end + 1]))
s = re.sub(r"@@FILE ([^@]+)@@", lambda m: open(here + "draft/" + m.group(1)).read().rstrip("\n"), s)
f = open(final).read()
a = f.index("// The strongly connected components")
b = f.index("\n}\n", a) + 2
s = s.replace("@@COMPONENTS@@", f[a:b].rstrip("\n"))
assert "@@" not in s
open(root + "/docs/superpowers/plans/nidana.model.12.md", "w").write(s)
print(len(s.splitlines()), "lines")
