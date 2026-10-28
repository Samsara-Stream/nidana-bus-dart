"""An independent derivation of topology-ir@v1's sample recordings (S154).

It never runs the producer. From HEAD's valid/ documents and the additions
S154 makes to two samples, written out by hand below from the conformance
library's declarations, it derives the new valid/every_combinator.json and
valid/escaping.json; from every valid/ document it derives the Mermaid and
Graphviz renderings by the contract's rules (Interface, Mermaid and Graphviz
rules). The producer's encoder and renderers are compared with the same files
by the behavior set's G19 and G22 cases and by the package's own tests.

usage:
  python3 -I independent.py write <head fixture dir> <fixture dir>
      derive the two documents and their four goldens into <fixture dir>,
      after checking that HEAD's other five samples' files derive unchanged
  python3 -I independent.py check <head fixture dir> <fixture dir>
      derive every sample's three files and compare them with <fixture dir>
"""
import copy
import json
import pathlib
import sys

VARIANTS = ["state", "event", "replay"]
SCOPES = ["application", "module", "page"]


def utf16(s):
    # String.compareTo compares UTF-16 code units; big-endian UTF-16 bytes
    # compare the same way.
    return s.encode("utf-16-be")


def topic_key(t):
    return (utf16(t["name"]), VARIANTS.index(t["variant"]), utf16(t["typeName"]))


def topic(name, variant, type_name):
    return {"name": name, "variant": variant, "typeName": type_name}


def dart_json(doc):
    # JsonEncoder.withIndent('  ') followed by a newline (The JSON form).
    return json.dumps(doc, indent=2, ensure_ascii=False) + "\n"


# ------------------------------------------------------------ the additions


def extend_every_combinator(head):
    """S154's additions to every_combinator, as the conformance library
    declares them: after HEAD's last statement, a read of the event topic
    every.count used twice by a merge, a switchMap with ticks and an
    anonymous retry, a throttle of 1500 ms, a map by label, and writes of the
    throttle to every.retried (event int) and of the map to every.retried
    (event String)."""
    doc = copy.deepcopy(head)
    t = doc["topologies"][0]
    assert t["topologyId"] == "every-combinator"
    edges = t["transforms"]
    first_sink = next(i for i, e in enumerate(edges) if "output" in e)
    assert first_sink == 22 and all("output" in e for e in edges[first_sink:])
    stages, sinks = edges[:first_sink], edges[first_sink:]
    count_events = topic("every.count", "event", "int")
    retried = topic("every.retried", "event", "int")
    retried_text = topic("every.retried", "event", "String")
    new_stages = [
        {"combinator": "merge", "inputs": [{"topic": count_events}, {"topic": count_events}]},
        {"combinator": "switchMap", "inputs": [{"edge": 22}], "transformer": {"name": "ticks"},
         "retry": {"name": None}},
        {"combinator": "throttle", "inputs": [{"edge": 23}], "durationMicros": 1500000},
        {"combinator": "map", "inputs": [{"edge": 24}], "transformer": {"name": "label"}},
    ]
    new_sinks = [
        {"inputs": [{"edge": 24}], "output": retried},
        {"inputs": [{"edge": 25}], "output": retried_text},
    ]
    t["transforms"] = stages + new_stages + sinks + new_sinks
    t["reads"] = sorted(t["reads"] + [count_events], key=topic_key)
    t["writes"] = sorted(t["writes"] + [retried, retried_text], key=topic_key)
    return doc


def extend_escaping(head):
    """S154's addition to escaping: a last write of the to$Label map (edge
    0) to the event topic odd.it's [a|b] & c, of type String."""
    doc = copy.deepcopy(head)
    t = doc["topologies"][1]
    assert t["topologyId"] == 'odd "quoted" #1 <tag> back\\slash café'
    assert t["transforms"][0]["transformer"] == {"name": "to$Label"}
    marks = topic("odd.it's [a|b] & c", "event", "String")
    t["transforms"].append({"inputs": [{"edge": 0}], "output": marks})
    t["writes"] = sorted(t["writes"] + [marks], key=topic_key)
    return doc


EXTENDED = {"every_combinator": extend_every_combinator, "escaping": extend_escaping}

# ------------------------------------------------------------ the renderings


def duration(micros):
    if micros % 1000000 == 0:
        return f"{micros // 1000000}s"
    if micros % 1000 == 0:
        return f"{micros // 1000}ms"
    return f"{micros}us"


def fn(ref):
    return "(anonymous)" if ref["name"] is None else ref["name"]


def topic_label(t):
    return [t["name"], f"{t['variant']} {t['typeName']}"]


def edge_label(e):
    first = e.get("combinator", "write")
    if "durationMicros" in e:
        first += " " + duration(e["durationMicros"])
    lines = [first]
    if "transformer" in e:
        lines.append(fn(e["transformer"]))
    if "retry" in e:
        lines.append("retry " + fn(e["retry"]))
    return lines


def mermaid_label(lines):
    def esc(s):
        for a, b in (("#", "#35;"), ('"', "#quot;"), ("<", "#lt;"), (">", "#gt;"), ("\n", "#10;")):
            s = s.replace(a, b)
        return s
    return "<br/>".join(esc(line) for line in lines)


def graphviz_label(lines):
    def esc(s):
        for a, b in (("\\", "\\\\"), ('"', '\\"'), ("\n", "\\n")):
            s = s.replace(a, b)
        return s
    return "\\n".join(esc(line) for line in lines)


def claim_key(c):
    return (utf16(c["source"]), SCOPES.index(c["scope"]), [topic_key(t) for t in sorted(c["writes"], key=topic_key)])


def parts(doc):
    topologies = sorted(doc["topologies"], key=lambda t: utf16(t["topologyId"]))
    claims = sorted(doc["claims"], key=claim_key)
    seen = {}
    for t in topologies:
        for r in t["reads"] + t["writes"]:
            seen[json.dumps(r, sort_keys=True)] = r
    for c in claims:
        for w in c["writes"]:
            seen[json.dumps(w, sort_keys=True)] = w
    topics = sorted(seen.values(), key=topic_key)
    ids = {json.dumps(t, sort_keys=True): f"t{i}" for i, t in enumerate(topics)}
    tid = lambda t: ids[json.dumps(t, sort_keys=True)]
    arrows = []  # (from, to, dedup or None)
    for j, t in enumerate(topologies):
        for k, e in enumerate(t["transforms"]):
            for i in e["inputs"]:
                if "topic" in i:
                    arrows.append((tid(i["topic"]), f"p{j}e{k}", i.get("dedup")))
                else:
                    arrows.append((f"p{j}e{i['edge']}", f"p{j}e{k}", None))
            if "output" in e:
                arrows.append((f"p{j}e{k}", tid(e["output"]), None))
    for m, c in enumerate(claims):
        for w in sorted(c["writes"], key=topic_key):
            arrows.append((f"s{m}", tid(w), None))
    return topics, topologies, claims, arrows


def mermaid(doc):
    topics, topologies, claims, arrows = parts(doc)
    out = ["flowchart LR"]
    out += [f'  t{i}(["{mermaid_label(topic_label(t))}"])' for i, t in enumerate(topics)]
    for j, t in enumerate(topologies):
        out.append(f'  subgraph p{j}["{mermaid_label([t["topologyId"], t["scope"]])}"]')
        out += [f'    p{j}e{k}["{mermaid_label(edge_label(e))}"]' for k, e in enumerate(t["transforms"])]
        out.append("  end")
    out += [f'  s{m}["{mermaid_label([c["source"], c["scope"]])}"]' for m, c in enumerate(claims)]
    for a, b, d in arrows:
        out.append(f"  {a} --> {b}" if d is None else f"  {a} -->|dedup {d}| {b}")
    return "".join(line + "\n" for line in out)


def graphviz(doc):
    topics, topologies, claims, arrows = parts(doc)
    out = ["digraph topologies {", "  rankdir=LR;"]
    out += [f'  t{i} [shape=ellipse, label="{graphviz_label(topic_label(t))}"];' for i, t in enumerate(topics)]
    for j, t in enumerate(topologies):
        out.append(f"  subgraph cluster_p{j} {{")
        out.append(f'    label="{graphviz_label([t["topologyId"], t["scope"]])}";')
        out += [f'    p{j}e{k} [shape=box, label="{graphviz_label(edge_label(e))}"];'
                for k, e in enumerate(t["transforms"])]
        out.append("  }")
    out += [f'  s{m} [shape=box, style=rounded, label="{graphviz_label([c["source"], c["scope"]])}"];'
            for m, c in enumerate(claims)]
    for a, b, d in arrows:
        out.append(f"  {a} -> {b};" if d is None else f'  {a} -> {b} [label="dedup {d}"];')
    out.append("}")
    return "".join(line + "\n" for line in out)


# ------------------------------------------------------------ main


def derive(head_dir):
    """Every sample's three files, derived: name -> {relative path: text}."""
    files = {}
    for path in sorted((head_dir / "valid").glob("*.json")):
        name = path.stem
        head_text = path.read_text(encoding="utf-8")
        head = json.loads(head_text)
        assert dart_json(head) == head_text, f"{name}: HEAD's text is not the indented form"
        doc = EXTENDED[name](head) if name in EXTENDED else head
        files[name] = {
            f"valid/{name}.json": dart_json(doc),
            f"render/{name}.mmd": mermaid(doc),
            f"render/{name}.dot": graphviz(doc),
        }
    return files


def main():
    mode, head_dir, fixture_dir = sys.argv[1], pathlib.Path(sys.argv[2]), pathlib.Path(sys.argv[3])
    files = derive(head_dir)
    failures = 0
    for name in EXTENDED:
        head = json.loads((head_dir / f"valid/{name}.json").read_text(encoding="utf-8"))
        for rel, text in ((f"render/{name}.mmd", mermaid(head)), (f"render/{name}.dot", graphviz(head))):
            same = text == (head_dir / rel).read_text(encoding="utf-8")
            print(f"{'AGREE' if same else 'DIFFER'} {rel} of HEAD: derived from HEAD's valid/ and equal to HEAD's file")
            failures += not same
    for name, texts in files.items():
        for rel, text in texts.items():
            target = fixture_dir / rel
            head_text = (head_dir / rel).read_text(encoding="utf-8")
            if name not in EXTENDED:
                same = text == head_text
                print(f"{'AGREE' if same else 'DIFFER'} {rel}: derived from HEAD's valid/ and equal to HEAD's file")
                failures += not same
            elif mode == "write":
                target.write_text(text, encoding="utf-8")
                print(f"WROTE {rel}: {len(text.splitlines())} lines (HEAD {len(head_text.splitlines())})")
            if mode == "check":
                same = target.read_text(encoding="utf-8") == text
                print(f"{'AGREE' if same else 'DIFFER'} {rel}: derived, against {fixture_dir.name}/{rel}")
                failures += not same
    print(f"{failures} differences")
    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    main()
