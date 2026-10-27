"""Summarizes one `--reporter json` run of package:test read from stdin.

Prints the lines that are not JSON events, the count of each event type, the
suite paths, every test with its hidden flag and result, the first line of
each error (with isFailure), and the done event's success. With --kinds, it
also classifies each failing visible test by its first error: UnimplementedError,
an expectation failure (isFailure true), or another error, with up to three
examples of each.
Usage: <runner> --reporter json ... | python3 -I summarize.py [--kinds]
"""
import json
import sys

kinds = "--kinds" in sys.argv
other_lines = []
events = []
for raw in sys.stdin.read().splitlines():
    try:
        value = json.loads(raw)
    except ValueError:
        other_lines.append(raw)
        continue
    if isinstance(value, dict) and "type" in value:
        events.append(value)
    else:
        other_lines.append(raw)

print("non-JSON stdout lines: %d" % len(other_lines))
for line in other_lines[:3]:
    print("  | " + line[:160])
types = {}
for e in events:
    types[e["type"]] = types.get(e["type"], 0) + 1
print("events: " + ", ".join("%s %d" % (k, v) for k, v in sorted(types.items())))
for e in events:
    if e["type"] == "suite":
        print("suite path: %s (platform %s)" % (e["suite"]["path"], e["suite"]["platform"]))
tests = {}
order = []
for e in events:
    if e["type"] == "testStart":
        t = e["test"]
        tests[t["id"]] = {"name": t["name"], "groupIDs": t["groupIDs"], "errors": []}
        order.append(t["id"])
    elif e["type"] == "error":
        tests[e["testID"]]["errors"].append((e["isFailure"], e["error"]))
    elif e["type"] == "testDone":
        tests[e["testID"]].update(result=e["result"], hidden=e["hidden"], skipped=e["skipped"])
visible = [tests[i] for i in order if not tests[i].get("hidden")]
hidden = [tests[i] for i in order if tests[i].get("hidden")]
print("hidden tests: %d (%s)" % (len(hidden), "; ".join("%r %s" % (t["name"], t.get("result")) for t in hidden)))
passed = sum(1 for t in visible if t.get("result") == "success" and not t.get("skipped"))
failed = sum(1 for t in visible if t.get("result") in ("failure", "error"))
skipped = sum(1 for t in visible if t.get("skipped"))
print("visible tests: %d: %d passed, %d failed, %d skipped" % (len(visible), passed, failed, skipped))
if not kinds:
    for t in visible:
        first = ""
        if t["errors"]:
            is_failure, text = t["errors"][0]
            first = " | isFailure=%s: %s" % (is_failure, text.strip().splitlines()[0][:150] if text.strip() else "")
        print("  %s %r groupIDs=%s%s" % (t.get("result"), t["name"], t["groupIDs"], first))
else:
    buckets = {"UnimplementedError": [], "expectation (isFailure)": [], "other error": []}
    for t in visible:
        if t.get("result") not in ("failure", "error"):
            continue
        is_failure, text = t["errors"][0] if t["errors"] else (False, "")
        first = text.strip().splitlines()[0] if text.strip() else ""
        if first.startswith("UnimplementedError"):
            key = "UnimplementedError"
        elif is_failure:
            key = "expectation (isFailure)"
        else:
            key = "other error"
        flat = " ".join(line.strip() for line in text.strip().splitlines()[:3])
        buckets[key].append("%s | %s" % (t["name"], flat[:170]))
    for key, items in buckets.items():
        print("  %s: %d" % (key, len(items)))
        for item in items[:3]:
            print("    e.g. " + item)
done = [e for e in events if e["type"] == "done"]
print("done: %s" % ("success=%s" % done[-1]["success"] if done else "no done event"))
