"""sweep-adr-001, part L: read-only checks over a committed tree's
hsdd/contract/ (the path given as the one argument), for the readings S155
states in ADR-001. Each check prints its finding; none changes a file.

  L1 every conformance library is imported, by a relative path, by at least
     one binding of some slug (S118's reading; behavior-set-plan R7 again)
  L2 no Dart fixture holds an import or export with a configuration
     (`if (...)`), whose URI the replay tool does not read (S119)
  L3 no Case table names a case in more than one row (S122)
  L4 every files/analysis_options.yaml with a plugins section opens it with
     a line that is exactly `plugins:` (S122)
  L5 every `- file:` bullet ends with a covers clause, and every Case row's
     Covers cell begins with ids, so no committed file replay or recorded
     invocation declares no id (S122)
  L6 no recorded invocation with files/ runs `dart run` (S121)
  L7 how many recorded invocations have files/, and which commands they run
"""
import pathlib
import re
import sys

root = pathlib.Path(sys.argv[1])
contract = root / 'hsdd' / 'contract'
fixture = contract / 'fixture'

directive = re.compile(r"^\s*(import|export)\s+'([^']+)'", re.M)
configured = re.compile(r"^\s*(import|export)\s+'[^']+'\s*\n?\s*if\s*\(", re.M)

print('### L1 conformance libraries and the bindings that import them')
suites = sorted(fixture.glob('*/behavior/*_conformance.dart'))
bound = {}
for binding in sorted(fixture.glob('*/behavior/*_test.dart')):
    for _, uri in directive.findall(binding.read_text()):
        if ':' in uri or uri.startswith('/'):
            continue
        target = (binding.parent / uri).resolve()
        bound.setdefault(target, []).append(binding.relative_to(root).as_posix())
for suite in suites:
    who = bound.get(suite.resolve(), [])
    print(f"{suite.relative_to(root).as_posix()}: {len(who)} binding(s) {who}")
unbound = [s for s in suites if s.resolve() not in bound]
print(f"conformance libraries: {len(suites)}; imported by no binding: {len(unbound)}")

print('\n### L2 Dart fixtures with a configured import or export')
dart = sorted(p for p in fixture.rglob('*.dart') if '/invocation/' not in p.as_posix() and '/input/' not in p.as_posix() and '/expected/' not in p.as_posix())
hits = [p for p in dart if configured.search(p.read_text(errors='replace'))]
print(f"Dart libraries the replay tool reads: {len(dart)}; with a configuration: {len(hits)} {[h.relative_to(root).as_posix() for h in hits]}")

print('\n### L3 Case tables that name a case twice')
def case_rows(text):
    lines = text.split('\n')
    try:
        start = lines.index('## Validation')
    except ValueError:
        return []
    section = []
    for line in lines[start + 1:]:
        if line.startswith('## '):
            break
        section.append(line)
    header = next((i for i, l in enumerate(section) if re.match(r'^\|\s*Case\s*\|', l)), None)
    if header is None:
        return []
    cells = [c.strip() for c in section[header].split('|')]
    covers = cells.index('Covers') if 'Covers' in cells else -1
    rows = []
    for line in section[header + 2:]:
        if not line.startswith('|'):
            break
        row = [c.strip() for c in line.split('|')]
        rows.append((row[1], row[covers] if 0 <= covers < len(row) else ''))
    return rows
for text_path in sorted(contract.glob('*.md')):
    rows = case_rows(text_path.read_text())
    if not rows:
        continue
    names = [r[0] for r in rows]
    repeated = sorted({n for n in names if names.count(n) > 1})
    print(f"{text_path.name}: {len(rows)} rows, repeated {repeated}")

print('\n### L4 plugins sections of files/analysis_options.yaml')
for options in sorted(fixture.glob('*/invocation/*/files/**/analysis_options.yaml')) + sorted(fixture.glob('*/invocation/*/files/analysis_options.yaml')):
    lines = options.read_text().split('\n')
    plugin_lines = [l for l in lines if l.lstrip().startswith('plugins')]
    if plugin_lines:
        print(f"{options.relative_to(root).as_posix()}: {plugin_lines} exact={'plugins:' in lines}")
print('(an options file without a plugins line is not listed)')

print('\n### L5 file replays and recorded invocations that declare no id')
ids = re.compile(r'^G[1-9][0-9]*( to G[1-9][0-9]*)?((, | and )G[1-9][0-9]*( to G[1-9][0-9]*)?)*$')
for text_path in sorted(contract.glob('*.md')):
    text = text_path.read_text()
    for line in text.split('\n'):
        if line.startswith('- file: '):
            clause = re.search(r'\bcovers ([^.]*)\.$', line)
            print(f"{text_path.name} - file: bullet covers clause: {clause.group(1) if clause else None}")
    rows = case_rows(text)
    without = [n for n, c in rows if not ids.match(c.split(': ')[0])]
    if rows:
        print(f"{text_path.name}: rows whose Covers cell begins with no ids: {without}")

print('\n### L6 and L7 recorded invocations: files/ and the command')
kinds = {}
for args in sorted(fixture.glob('*/invocation/*/args')):
    lines = args.read_text().split('\n')
    has_files = (args.parent / 'files').is_dir()
    head = lines[0] if lines[0] in ('dart', 'flutter') else '{package}:{executable}'
    second = lines[1] if len(lines) > 1 and lines[0] == 'dart' else ''
    key = (head, second, has_files)
    kinds[key] = kinds.get(key, 0) + 1
for (head, second, has_files), n in sorted(kinds.items()):
    print(f"{n:3} {head} {second} {'with files/' if has_files else 'from the root'}")
dart_run = [a for a in fixture.glob('*/invocation/*/args') if a.read_text().split('\n')[:2] == ['dart', 'run']]
print(f"recorded invocations whose command is dart run: {len(dart_run)}")
