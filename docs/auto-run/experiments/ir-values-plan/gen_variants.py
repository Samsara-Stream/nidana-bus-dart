# Derives draft/lib/src/ir/definition.t2.dart, the library after Task 2 of
# the nidana.model.10 plan: TopicInput, StageInput and TransformEdge as in the
# final draft, TopologyDefinition as committed at HEAD (its factory throws,
# its ignore comment stays) and no import of canonical_order.dart, which
# Task 3 creates. Run by run.sh: python3 -I gen_variants.py <repo>
import subprocess
import sys

repo = sys.argv[1]
here = repo + '/docs/auto-run/experiments/ir-values-plan/draft/lib/src/ir/'
final = open(here + 'definition.dart').read()
head = subprocess.run(
    ['git', '-C', repo, 'show', 'HEAD:packages/nidana_dart_contracts/lib/src/ir/definition.dart'],
    check=True, capture_output=True, text=True).stdout
mark = '/// The IR of one topology'
t2 = final[:final.index(mark)] + head[head.index(mark):]
t2 = t2.replace("import 'canonical_order.dart';\n", '')
open(here + 'definition.t2.dart', 'w').write(t2)
print('definition.t2.dart: %d lines' % t2.count('\n'))
