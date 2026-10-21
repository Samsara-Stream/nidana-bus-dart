#!/usr/bin/env python3
"""build.py: build the run explorer's data from the repository, the ledger and
the session transcripts.

Usage (from the repository root):
    python3 docs/auto-run/explorer/build.py <session-dir> <out-dir>

<session-dir> is ~/.claude*/projects/<project>/<session-id>: it holds
subagents/*.jsonl (one transcript per step subagent), and its .jsonl sibling is
the orchestrator's transcript. <out-dir> receives index.html, local.html and
data/. Serve <out-dir> over HTTP to view it locally (the page fetches data/).

Only the RUN block below is specific to this run.
"""
import collections
import datetime as dt
import glob
import json
import os
import re
import shutil
import subprocess
import sys

ROOT = os.getcwd()
HERE = os.path.dirname(os.path.abspath(__file__))
SESSION = sys.argv[1].rstrip("/")
OUT = sys.argv[2]
MAIN_TX = SESSION + ".jsonl"
HOME = os.path.expanduser("~")

# ---------------------------------------------------------------- RUN ----
RUN = {
    "name": "nidana-bus-dart automatic HSDD planning run",
    "branch": "auto/v1-planning",
    "base": "main",
    "stages": [
        {"id": 0, "title": "Settle the inputs", "steps": ["S00"],
         "summary": "The orchestrator reads the repository, the three v0.15.0 reference documents and the HSDD skills, writes the step preamble every subagent receives, and records how it reads its own stop rules (DEC-001 to DEC-004)."},
        {"id": 1, "title": "Execution plan and run tooling", "steps": ["S01"],
         "summary": "Before any skill runs, the orchestrator commits the execution plan, the gate (gate.mjs) and the ledger tool (ledger.mjs), and decides planning order, reconcile cadence and step granularity (DEC-005 to DEC-010)."},
        {"id": 2, "title": "Root decomposition", "steps": ["S02"],
         "summary": "One subagent runs hsdd-spec in root mode: v1 scope, six children, the typed DAG, nine contract ids, three proposed ADRs and the open questions."},
        {"id": 3, "title": "Root ADRs", "steps": ["S03", "S04", "S05"],
         "summary": "One hsdd-adr step per ADR the root proposed: executable contract validation, package and workspace layout, time source and virtual scheduler. Each rests on experiments run through fvm."},
        {"id": 4, "title": "Root contracts and touch-ups", "steps": ["S%02d" % i for i in range(6, 22)],
         "summary": "Nine contracts authored producer-first, two compatible amendments inserted when a consumer contract needed them (S10, S13), then a touch-up batch of two ADR updates and three contract touches (S17 to S21)."},
        {"id": 5, "title": "Mid-level decomposition", "steps": ["S%02d" % i for i in range(22, 28)],
         "summary": "nidana.runtime becomes a leaf-parent (reversing root D4, a run-stop candidate judged not to hold), nidana.tooling splits into codegen and lint, two ADR updates follow, and the root is refreshed."},
        {"id": 6, "title": "Phase plans, each followed by reconcile", "steps": ["S%02d" % i for i in range(28, 43)],
         "summary": "Seven leaf-parents planned producer-first, each followed by hsdd-reconcile on its pending governance section. S38 (an ADR-002 amendment) was inserted when constraint lower bounds stopped resolving. S42 leaves every contract stable and final."},
        {"id": 7, "title": "Consistency pass and final sweep", "steps": ["S%02d" % i for i in range(43, 54)],
         "summary": "Text the stage-6 steps found stale goes through its owning skill: one ADR, three contracts, six node specs, then one hsdd-reconcile sweep of every phase scope and gate (DEC-603 to DEC-606)."},
        {"id": 8, "title": "Report", "steps": ["S54"],
         "summary": "The orchestrator generates REPORT.md from the ledger and the step reports, commits it, and stops the loop."},
    ],
    "inserted": {
        "S10": "S09 (bus-api@v1) needed a sealed MultiWriterTopic in topic-model@v1.",
        "S13": "S12 (navigation-api@v1) found bus-api@v1 lacked a pre-start connection guarantee and widened publish<T>.",
        "S27": "The root refresh (S26) left the topology-ir@v1 edges into navigation and flutter unrecorded.",
        "S38": "ADR-002's rule for constraint lower bounds produced constraints that stop resolving once a Flutter member joins.",
        "S46": "topic-codegen@v1 compared the registry after build_runner had rewritten it, so the check could never fail.",
        "S52": "nidana.tooling.codegen's Development flow still started the node on nidana.model's first phase.",
    },
    "run_stop_candidates": {"DEC-186": "S09", "DEC-193": "S10", "DEC-362": "S22", "DEC-373": "S23", "DEC-430": "S28", "DEC-471": "S31"},
    "contracts_by_node": {
        "nidana.model": ["topic-model@v1", "topology-dsl@v1", "topology-ir@v1"],
        "nidana.runtime": ["bus-api@v1", "bus-testing@v1"],
        "nidana.navigation": ["navigation-api@v1"],
        "nidana.flutter": ["flutter-binding@v1"],
        "nidana.tooling.codegen": ["topic-codegen@v1", "nidana-checks@v1 (scan share)"],
        "nidana.tooling.lint": ["nidana-checks@v1 (plugin share)"],
        "nidana.integration": [],
    },
}
# -------------------------------------------------------------------------

STEP_RE = re.compile(r"\b(S\d\d)\b")


def git(*args):
    return subprocess.run(["git", *args], capture_output=True, text=True, check=True, cwd=ROOT).stdout


def utc(ts):
    """Any ISO timestamp to 'YYYY-MM-DDTHH:MM:SSZ'."""
    if not ts:
        return None
    t = dt.datetime.fromisoformat(ts.replace("Z", "+00:00"))
    return t.astimezone(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def rel(p):
    if not isinstance(p, str):
        return ""
    for pre in (ROOT + "/", "/private" + ROOT + "/"):
        if p.startswith(pre):
            return p[len(pre):]
    if p.startswith(HOME):
        return "~" + p[len(HOME):]
    return p


def short(s, n):
    s = s if isinstance(s, str) else json.dumps(s)
    return s if len(s) <= n else s[: n - 1] + "…"


def read(path):
    with open(os.path.join(ROOT, path), encoding="utf-8", errors="replace") as f:
        return f.read()


def dump(name, obj):
    path = os.path.join(OUT, "data", name)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(obj, f, ensure_ascii=False, separators=(",", ":"))
    return os.path.getsize(path)


# ---------------------------------------------------------------- git ----
def commits():
    out = git("log", "--reverse", "--format=%x1e%h%x1f%cI%x1f%s", "--numstat", f"{RUN['base']}..HEAD")
    status = git("log", "--reverse", "--format=%x1e%h", "--name-status", f"{RUN['base']}..HEAD")
    st = {}
    for rec in status.split("\x1e")[1:]:
        lines = rec.strip().split("\n")
        st[lines[0]] = {}
        for l in lines[1:]:
            if not l.strip():
                continue
            parts = l.split("\t")
            st[lines[0]][parts[-1]] = parts[0][0]
    res = []
    for rec in out.split("\x1e")[1:]:
        lines = rec.strip("\n").split("\n")
        sha, date, subj = lines[0].split("\x1f")
        files = []
        for l in lines[1:]:
            if not l.strip():
                continue
            a, d, p = l.split("\t", 2)
            files.append({"p": p, "a": None if a == "-" else int(a), "d": None if d == "-" else int(d), "s": st.get(sha, {}).get(p, "M")})
        m = re.match(r"(hsdd|judgement|auto-run|chore): (S\d\d)?", subj)
        kind = m.group(1) if m else "other"
        res.append({"sha": sha, "at": utc(date), "subject": subj, "kind": kind, "step": m.group(2) if m and m.group(2) else None, "files": files})
    return res


# --------------------------------------------------------- transcripts ----
def entries(path):
    with open(path, encoding="utf-8") as f:
        for line in f:
            try:
                yield json.loads(line)
            except json.JSONDecodeError:
                continue


USAGE_KEYS = ("input_tokens", "output_tokens", "cache_read_input_tokens", "cache_creation_input_tokens")


def usage_add(acc, seen, e):
    """Add one API response's usage once. A streamed response is written as several entries sharing
    a message id, and only the last carries the final output count, so the maximum per id is kept."""
    msg = e.get("message", {})
    mid = msg.get("id")
    u = msg.get("usage")
    if not u:
        return
    prev = seen.get(mid, {})
    for k in USAGE_KEYS:
        v = u.get(k) or 0
        if v > prev.get(k, 0):
            acc[k] = acc.get(k, 0) + v - prev.get(k, 0)
            prev[k] = v
    seen[mid] = prev


EXP_RE = re.compile(r"docs/auto-run/experiments/([\w.@+-]+)")


def classify_sub(name, inp):
    """A subagent tool call as (kind, label, detail)."""
    if name == "Skill":
        return "skill", inp.get("skill", ""), short(inp.get("args", ""), 1500)
    if name == "Read":
        p = rel(inp.get("file_path", ""))
        if p.startswith("ref/"):
            k = "read-source"
        elif ".agents/skills" in p or p.startswith("~/git/hsdd"):
            k = "read-method"
        elif p.startswith("docs/auto-run/experiments/"):
            k = "experiment"
        else:
            k = "read"
        rng = ""
        if inp.get("offset") or inp.get("limit"):
            rng = f" lines {inp.get('offset', 1)}+{inp.get('limit', '')}"
        return k, p + rng, None
    if name in ("Grep", "Glob"):
        return "search", short(inp.get("pattern", ""), 160), rel(inp.get("path", "")) or None
    if name == "Write":
        p = rel(inp.get("file_path", ""))
        n = len((inp.get("content") or "").splitlines())
        if p.startswith("docs/auto-run/steps/"):
            return "report", p, f"{n} lines"
        if p.startswith("docs/auto-run/experiments/"):
            return "experiment", p, f"wrote {n} lines"
        return "write", p, f"{n} lines"
    if name in ("Edit", "MultiEdit"):
        p = rel(inp.get("file_path", ""))
        if p.startswith("docs/auto-run/experiments/"):
            return "experiment", p, "edited"
        old = len((inp.get("old_string") or "").splitlines())
        new = len((inp.get("new_string") or "").splitlines())
        return "edit", p, f"-{old} +{new} lines"
    if name == "Bash":
        cmd = inp.get("command", "")
        desc = inp.get("description", "")
        label = desc or short(cmd.split("\n")[0], 140)
        detail = short(cmd, 1200)
        if re.fullmatch(r"\s*date -u[^\n|;&]*", cmd):
            return "clock", "takes a UTC timestamp", detail
        if "gate.mjs" in cmd:
            return "gate", label, detail
        if "gen-registry" in cmd:
            return "registry", label, detail
        m = EXP_RE.search(cmd)
        if m:
            return "experiment", m.group(1) + ": " + label, detail
        if re.search(r"\bfvm\b", cmd):
            return "toolchain", label, detail
        if re.match(r"\s*(cd [^&;]+&&\s*)?git\b", cmd):
            return "git-read", label, detail
        return "inspect", label, detail
    if name == "SubagentHandback":
        return "handback", "hands back to the orchestrator", short(json.dumps(inp), 1500)
    return "other", name, short(json.dumps(inp), 400)


def classify_orch(name, inp):
    if name == "Agent":
        return "dispatch", inp.get("description", ""), None
    if name == "ScheduleWakeup":
        return "wait", f"sleeps {inp.get('delaySeconds', '?')}s" if not inp.get("stop") else "stops the loop", inp.get("reason")
    if name in ("Write", "Edit"):
        p = rel(inp.get("file_path", ""))
        if p.endswith(".section.md") or "-common.md" in p:
            return "prompt", "writes the step prompt " + os.path.basename(p), p
        if p.endswith("execution-plan.md"):
            return "plan", "updates the execution plan", p
        if re.search(r"steps/S\d\d\.(orchestrator|plan)\.json$", p):
            return "judge", "records its own decisions in " + os.path.basename(p), p
        if p.endswith("REPORT.md") or "report" in os.path.basename(p):
            return "report", "writes the report " + os.path.basename(p), p
        if "/tools/" in p:
            return "tooling", "changes run tooling " + os.path.basename(p), p
        return "write", "writes " + p, p
    if name == "Read":
        return "review", "reads " + rel(inp.get("file_path", "")), None
    if name == "Bash":
        cmd = inp.get("command", "")
        desc = inp.get("description", "")
        label = desc or short(cmd.split("\n")[0], 140)
        detail = short(cmd, 1500)
        m = re.search(r"git commit[^\n]*?-m\s+[\"']([^\"'\n]+)", cmd) or re.search(r"git commit[^\n]*?-F", cmd)
        if m:
            msg = m.group(1) if m.groups() else "commit"
            return "commit", msg, detail
        if "gate.mjs" in cmd:
            return "gate", label, detail
        if "ledger.mjs" in cmd:
            return "ledger", label, detail
        if "gen-registry" in cmd:
            return "registry", label, detail
        if re.fullmatch(r"\s*date -u[^\n|;&]*", cmd):
            return "clock", "takes a UTC timestamp", detail
        if re.search(r"\bgit (status|log|diff|show)\b", cmd):
            return "git-read", label, detail
        return "review", label, detail
    if name == "Artifact":
        return "other", "Artifact", None
    return "other", name, short(json.dumps(inp), 300)


def subagents():
    res = {}
    for meta_path in sorted(glob.glob(os.path.join(SESSION, "subagents", "*.meta.json"))):
        meta = json.load(open(meta_path))
        m = re.match(r"(S\d\d)", meta.get("description", ""))
        if not m:
            continue
        step = m.group(1)
        tx = meta_path.replace(".meta.json", ".jsonl")
        events, errs, usage, seen = [], {}, {}, {}
        first = last = None
        prompt = None
        final_text = ""
        for e in entries(tx):
            ts = utc(e.get("timestamp"))
            if ts:
                first = first or ts
                last = ts
            t = e.get("type")
            if t == "user":
                c = e["message"].get("content")
                if prompt is None and isinstance(c, str):
                    prompt = c
                if isinstance(c, list):
                    for b in c:
                        if isinstance(b, dict) and b.get("type") == "tool_result" and b.get("is_error"):
                            errs[b.get("tool_use_id")] = True
            elif t == "assistant":
                usage_add(usage, seen, e)
                for b in e["message"].get("content", []):
                    if b.get("type") == "text" and b.get("text", "").strip():
                        final_text = b["text"]
                        events.append({"t": ts, "k": "note", "l": short(b["text"].strip(), 600)})
                    elif b.get("type") == "tool_use":
                        k, l, d = classify_sub(b["name"], b.get("input", {}))
                        ev = {"t": ts, "k": k, "l": l, "id": b.get("id")}
                        if d:
                            ev["d"] = d
                        events.append(ev)
        for ev in events:
            if errs.get(ev.pop("id", None)):
                ev["err"] = True
        counts = collections.Counter(ev["k"] for ev in events)
        res[step] = {"agent": os.path.basename(tx)[:-6], "description": meta.get("description"),
                     "start": first, "end": last, "events": events, "counts": dict(counts),
                     "usage": usage, "final": short(final_text, 4000)}
    return res


def orchestrator():
    """Main-session events: (ts, kind, label, detail), plus prompts per step and compactions."""
    events, prompts, compactions, usage_by_ts = [], {}, [], []
    seen = {}
    for e in entries(MAIN_TX):
        if e.get("isSidechain"):
            continue
        ts = utc(e.get("timestamp"))
        t = e.get("type")
        if t == "system" and e.get("subtype") == "compact_boundary":
            compactions.append(ts)
            events.append({"t": ts, "k": "compact", "l": "context summarized; resumes from the plan, ledger and git log"})
        elif t == "system" and e.get("subtype") == "scheduled_task_fire":
            events.append({"t": ts, "k": "wake", "l": "wakes up and checks the running step"})
        elif t == "assistant":
            u = {}
            usage_add(u, seen, e)
            if u:
                usage_by_ts.append((ts, u))
            for b in e["message"].get("content", []):
                if b.get("type") == "text" and b.get("text", "").strip():
                    events.append({"t": ts, "k": "note", "l": short(b["text"].strip(), 600)})
                elif b.get("type") == "tool_use":
                    inp = b.get("input", {})
                    k, l, d = classify_orch(b["name"], inp)
                    ev = {"t": ts, "k": k, "l": l}
                    if d:
                        ev["d"] = d
                    events.append(ev)
                    if b["name"] == "Agent":
                        m = re.match(r"(S\d\d)", inp.get("description", ""))
                        if m:
                            prompts[m.group(1)] = inp.get("prompt", "")
    return events, prompts, compactions, usage_by_ts


# ------------------------------------------------------------- content ----
TEXT_EXT = (".md", ".dart", ".json", ".yaml", ".yml", ".txt", ".mjs", ".js", ".py", ".sh", ".toml", ".html", ".csv", ".jsonl", ".out", ".log", ".lock")


def is_text(p):
    return p.endswith(TEXT_EXT) or "." not in os.path.basename(p)


def file_bundle(paths, cap=400_000):
    res = {}
    for p in paths:
        if not os.path.isfile(os.path.join(ROOT, p)) or not is_text(p):
            continue
        s = read(p)
        res[p] = s if len(s) <= cap else s[:cap] + f"\n\n[truncated at {cap} characters of {len(s)}]"
    return res


def experiments(commit_list, decisions):
    tracked = [p for p in git("ls-files", "docs/auto-run/experiments").splitlines()]
    by = collections.defaultdict(list)
    for p in tracked:
        m = EXP_RE.match(p)
        if m:
            by[m.group(1)].append(p)
    steps_by = collections.defaultdict(set)
    for c in commit_list:
        for f in c["files"]:
            m = EXP_RE.match(f["p"])
            if m and c["step"]:
                steps_by[m.group(1)].add(c["step"])
    cites = collections.defaultdict(list)
    for d in decisions:
        for ev in d.get("evidence", []):
            m = EXP_RE.search(ev if isinstance(ev, str) else "")
            if m and d["id"] not in cites[m.group(1)]:
                cites[m.group(1)].append(d["id"])
    res = {}
    for name, files in sorted(by.items()):
        items, budget = [], 220_000
        files.sort(key=lambda p: (not p.endswith(("README.md", "output.txt")), p))
        for p in files:
            size = os.path.getsize(os.path.join(ROOT, p)) if os.path.exists(os.path.join(ROOT, p)) else 0
            item = {"p": p, "size": size}
            if is_text(p) and not p.endswith("pubspec.lock") and budget > 0:
                s = read(p)
                cut = min(len(s), 40_000, budget)
                item["c"] = s[:cut] + ("" if cut == len(s) else f"\n\n[truncated at {cut} of {len(s)} characters]")
                budget -= cut
            items.append(item)
        res[name] = {"files": items, "steps": sorted(steps_by.get(name, [])), "decisions": cites.get(name, [])}
    return res


def step_diff(sha, cap_file=120_000, cap_total=1_500_000):
    out = git("show", "--format=", "--patch", "--no-color", sha, "--", "hsdd/", "docs/auto-run/execution-plan.md")
    parts = re.split(r"(?m)^(?=diff --git )", out)
    res, total = [], 0
    for part in parts:
        if not part.strip():
            continue
        m = re.match(r"diff --git a/(\S+) b/(\S+)", part)
        path = m.group(2) if m else "?"
        body = part if len(part) <= cap_file else part[:cap_file] + f"\n[diff truncated at {cap_file} characters]"
        if total + len(body) > cap_total:
            res.append({"p": path, "patch": "[omitted: step diff budget exhausted]"})
            continue
        total += len(body)
        res.append({"p": path, "patch": body})
    return res


def tree():
    nodes = []
    for p in sorted(glob.glob(os.path.join(ROOT, "hsdd/spec/*.md"))):
        node = os.path.basename(p)[:-3]
        s = open(p, encoding="utf-8").read()
        km = re.search(r"^- \*\*Kind:\*\* (\S+)", s, re.M)
        phases = [{"id": f"{node}.{n}", "title": t.strip()} for n, t in re.findall(rf"^### {re.escape(node)}\.(\d+):(.*)$", s, re.M)]
        parent = node.rsplit(".", 1)[0] if "." in node else None
        nodes.append({"id": node, "kind": km.group(1) if km else "?", "parent": parent, "phases": phases,
                      "file": f"hsdd/spec/{node}.md", "contracts": RUN["contracts_by_node"].get(node, [])})
    return nodes


def changelog():
    s = read("docs/auto-run/execution-plan.md")
    body = s.split("## Change log", 1)[1]
    items = re.split(r"(?m)^- ", body)[1:]
    res = []
    for it in items:
        text = " ".join(l.strip() for l in it.strip().splitlines())
        m = re.search(r"after (S\d\d)|, (S\d\d):", text)
        res.append({"step": (m.group(1) or m.group(2)) if m else None, "text": text})
    return res


# ---------------------------------------------------------------- main ----
def main():
    os.makedirs(os.path.join(OUT, "data", "steps"), exist_ok=True)
    clist = commits()
    decisions = [json.loads(l) for l in open(os.path.join(ROOT, "hsdd/judgement/decisions.jsonl"))]
    runlog = [json.loads(l) for l in open(os.path.join(ROOT, "hsdd/judgement/run.jsonl"))]
    subs = subagents()
    oevents, prompts, compactions, ousage = orchestrator()
    preamble = read("docs/auto-run/step-preamble.md")

    stage_of = {s: st["id"] for st in RUN["stages"] for s in st["steps"]}
    art_commit = {c["step"]: c for c in clist if c["step"] and c["kind"] in ("hsdd", "auto-run")}
    jud_commit = {c["step"]: c for c in clist if c["step"] and c["kind"] == "judgement"}

    # Orchestrator decisions: every decision of a step whose questions appear in an orchestrator file.
    orch_q = set()
    for p in glob.glob(os.path.join(ROOT, "docs/auto-run/steps/*.orchestrator.json")) + glob.glob(os.path.join(ROOT, "docs/auto-run/steps/*.plan.json")):
        d = json.load(open(p))
        for x in (d if isinstance(d, list) else d.get("decisions", [])):
            orch_q.add(x.get("question"))
    for d in decisions:
        d["by"] = "orchestrator" if (d["question"] in orch_q or d["step"] in ("setup", "plan")) else "subagent"

    # Orchestrator events by step: an event belongs to the first step whose judgement commit is at or after it.
    order = [r["step_ref"] for r in runlog]
    bounds = [(s, jud_commit[s]["at"]) for s in order if s in jud_commit]
    end_of_run = bounds[-1][1]
    oby = collections.defaultdict(list)
    for ev in oevents:
        if not ev["t"] or ev["t"] > end_of_run:
            continue
        for s, b in bounds:
            if ev["t"] <= b:
                oby[s].append(ev)
                break
    ou_by = collections.defaultdict(dict)
    for ts, u in ousage:
        if ts > end_of_run:
            continue
        for s, b in bounds:
            if ts <= b:
                for k, v in u.items():
                    ou_by[s][k] = ou_by[s].get(k, 0) + v
                break

    clog = changelog()
    dec_by_step = collections.defaultdict(list)
    for d in decisions:
        dec_by_step[d["step_ref"]].append(d["id"])

    steps = []
    prev_end = None
    for r in runlog:
        s = r["step_ref"]
        ac, jc = art_commit.get(s), jud_commit.get(s)
        sub = subs.get(s)
        ev_orch = oby.get(s, [])
        start = (ev_orch[0]["t"] if ev_orch else None) or (sub["start"] if sub else None) or prev_end
        end = jc["at"] if jc else (ac["at"] if ac else None)
        prev_end = end
        touched = sorted({re.sub(r"\.md$", "", f["p"].split("/")[-1]) + "|" + f["p"].split("/")[1]
                          for f in (ac["files"] if ac else []) if f["p"].startswith(("hsdd/spec/", "hsdd/adr/", "hsdd/contract/")) and f["p"].endswith(".md") and "INDEX" not in f["p"]})
        exps = sorted({m.group(1) for f in (ac["files"] if ac else []) for m in [EXP_RE.match(f["p"])] if m})
        steps.append({
            "ref": s, "stage": stage_of.get(s), "skill": r["skill"], "target": r["target"],
            "dispatches": r.get("dispatches", 0), "recorded": {"started": r["started"], "finished": r["finished"]},
            "start": start, "end": end,
            "sub": None if not sub else {"start": sub["start"], "end": sub["end"], "counts": sub["counts"], "usage": sub["usage"], "agent": sub["agent"]},
            "orch_usage": ou_by.get(s, {}),
            "commits": {"artifact": ac and {"sha": ac["sha"], "at": ac["at"], "subject": ac["subject"]},
                        "judgement": jc and {"sha": jc["sha"], "at": jc["at"], "subject": jc["subject"]}},
            "files": [f for f in (ac["files"] if ac else []) if not f["p"].startswith("docs/auto-run/experiments/")],
            "experiments": exps,
            "touched": [t.split("|")[0] for t in touched],
            "decisions": dec_by_step.get(s, []),
            "inserted": RUN["inserted"].get(s),
            "learned": [c["text"] for c in clog if c["step"] == s],
        })

    for st in steps:
        s = st["ref"]
        bundle = {"ref": s, "orch": oby.get(s, []), "sub": subs.get(s, {}).get("events", []),
                  "final": subs.get(s, {}).get("final", ""), "prompt": None, "prompt_has_preamble": False,
                  "reports": {}, "diff": [], "judgement_files": []}
        p = prompts.get(s)
        if p:
            if preamble.strip() and preamble.strip()[:200] in p:
                bundle["prompt_has_preamble"] = True
                i = p.find("# Your step")
                bundle["prompt"] = p[i:] if i >= 0 else p.replace(preamble, "").strip()
            else:
                bundle["prompt"] = p
        for rp in sorted(glob.glob(os.path.join(ROOT, f"docs/auto-run/steps/{s}*.json"))):
            bundle["reports"][os.path.basename(rp)] = json.load(open(rp))
        if st["commits"]["artifact"]:
            bundle["diff"] = step_diff(st["commits"]["artifact"]["sha"])
        if st["commits"]["judgement"]:
            jc = jud_commit[s]
            bundle["judgement_files"] = jc["files"]
        dump(f"steps/{s}.json", bundle)

    history = collections.defaultdict(list)
    for c in clist:
        for f in c["files"]:
            if f["p"].startswith("docs/auto-run/experiments/"):
                continue
            history[f["p"]].append({"step": c["step"], "sha": c["sha"], "kind": c["kind"], "a": f["a"], "d": f["d"], "s": f["s"]})

    total_usage = {}
    for sub in subs.values():
        for k, v in sub["usage"].items():
            total_usage["sub_" + k] = total_usage.get("sub_" + k, 0) + v
    for u in ou_by.values():
        for k, v in u.items():
            total_usage["orch_" + k] = total_usage.get("orch_" + k, 0) + v

    core = {
        "run": {"name": RUN["name"], "branch": RUN["branch"], "base": RUN["base"],
                "head": git("rev-parse", "--short", "HEAD").strip(),
                "start": steps[0]["start"], "end": end_of_run, "compactions": [c for c in compactions if c <= end_of_run],
                "usage": total_usage},
        "stages": RUN["stages"],
        "steps": steps,
        "decisions": [{"id": d["id"], "s": d["step_ref"], "st": d["step"], "b": d["blast_radius"], "c": d["confidence"],
                       "w": d["would_have_asked"], "u": d.get("would_upstream", False), "sc": d.get("stop_class"),
                       "by": d["by"], "at": d["at"], "q": short(d["question"], 240), "ch": short(d["chosen"], 160),
                       "a": d.get("artifact")} for d in decisions],
        "run_stop_candidates": RUN["run_stop_candidates"],
        "tree": tree(),
        "history": history,
        "changelog": clog,
        "preamble": preamble,
    }
    sizes = {"core.json": dump("core.json", core), "decisions.json": dump("decisions.json", decisions)}

    gov = [p for p in git("ls-files", "hsdd").splitlines() if not p.startswith("hsdd/judgement/")]
    run_docs = [p for p in git("ls-files", "docs/auto-run").splitlines() if not p.startswith(("docs/auto-run/experiments/", "docs/auto-run/steps/", "docs/auto-run/explorer/"))]
    sizes["files-gov.json"] = dump("files-gov.json", file_bundle([p for p in gov if p.endswith(".md")] + run_docs))
    sizes["files-fixture.json"] = dump("files-fixture.json", file_bundle([p for p in gov if not p.endswith(".md")]))
    refs = sorted(glob.glob(os.path.join(ROOT, "ref/nidana-docs/arch/*-v0_15_0.md")))
    skills = sorted(glob.glob(os.path.join(ROOT, ".agents/skills/hsdd-*/**/*.md"), recursive=True))
    sizes["files-ref.json"] = dump("files-ref.json", file_bundle([rel(p) for p in refs + skills]))
    sizes["experiments.json"] = dump("experiments.json", experiments(clist, decisions))

    for name in ("index.html",):
        shutil.copy(os.path.join(HERE, name), os.path.join(OUT, name))
    with open(os.path.join(HERE, "index.html"), encoding="utf-8") as f:
        page = f.read()
    with open(os.path.join(OUT, "local.html"), "w", encoding="utf-8") as f:
        f.write("<!doctype html>\n<html lang=\"en\"><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width, initial-scale=1\"></head><body>\n" + page + "\n</body></html>\n")
    steps_total = sum(os.path.getsize(p) for p in glob.glob(os.path.join(OUT, "data/steps/*.json")))
    for k, v in sizes.items():
        print(f"{k:22s} {v / 1e6:6.2f} MB")
    print(f"{'steps/*.json':22s} {steps_total / 1e6:6.2f} MB")


if __name__ == "__main__":
    main()
