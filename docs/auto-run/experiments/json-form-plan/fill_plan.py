# fill_plan.py: writes docs/superpowers/plans/nidana.model.13.md from
# plan.template.md, filling @@CONSTRAINTS@@ with the derivative's Global
# Constraints 1 to 8 as written, each @@FILE path@@ with draft/<path>,
# @@SUPPORT_T1@@ and @@SUPPORT_GENERATED@@ with Task 1's and Task 2's parts
# of draft/test/src/json_support.dart, and @@INTEGER_T2@@, @@INTEGER@@ and
# @@BUILD@@ with those functions as variants.py's Task 2 codec.dart and the
# final draft hold them, so the plan's code is exactly what run.sh ran.
#   python3 -I fill_plan.py <repo root>
import subprocess
import sys
import tempfile

root = sys.argv[1]
here = root + "/docs/auto-run/experiments/json-form-plan/"
s = open(here + "plan.template.md").read()

der = open(root + "/hsdd-context/superpowers/nidana.model.13.md").read().split("\n")
start = next(i for i, l in enumerate(der) if l.startswith("1. Every plan task"))
end = next(i for i, l in enumerate(der) if l.startswith("8. Review tier"))
s = s.replace("@@CONSTRAINTS@@", "\n".join(der[start : end + 1]))

out = tempfile.mkdtemp()
subprocess.run(
    ["python3", "-I", here + "variants.py", here + "draft/lib/src/json/codec.dart",
     here + "draft/test/src/json_support.dart", out],
    check=True, stdout=subprocess.DEVNULL)
t2 = open(out + "/codec.t2.dart").read()
final = open(here + "draft/lib/src/json/codec.dart").read()
support = open(here + "draft/test/src/json_support.dart").read()


def block(text, first_line, last_line):
    a = text.index(first_line)
    b = text.index(last_line, a) + len(last_line)
    return text[a:b]


s = s.replace("@@SUPPORT_T1@@", open(out + "/json_support.t1.dart").read().rstrip("\n"))
marker = "// ------------------------------------------------------------ generated"
s = s.replace("@@SUPPORT_GENERATED@@", support[support.index(marker):].rstrip("\n"))
s = s.replace("@@INTEGER_T2@@", block(t2, "// [json] as an integer", "const double _twoTo63 = 9223372036854775808.0;"))
s = s.replace("@@INTEGER@@", block(final, "// [json] as a non-negative integer", "\n};"))
s = s.replace("@@BUILD@@", block(final, "// What [build] returns", "\n  }\n}"))
import re
s = re.sub(r"@@FILE ([^@]+)@@", lambda m: open(here + "draft/" + m.group(1)).read().rstrip("\n"), s)
assert "@@" not in s, s[s.index("@@") - 40 : s.index("@@") + 40]
open(root + "/docs/superpowers/plans/nidana.model.13.md", "w").write(s)
print(len(s.splitlines()), "lines")
