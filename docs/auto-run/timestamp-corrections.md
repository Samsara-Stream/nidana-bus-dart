# Timestamp corrections

The ledger (`hsdd/judgement/decisions.jsonl`, `hsdd/judgement/run.jsonl`) is append-only, so wrong
timestamps in it are corrected here, not in place.

**What went wrong.** From step S09 onward the orchestrator stamped its own decisions and the run log by
hand with the machine's local time (WIB, UTC+7) labelled as UTC (`Z`), so those values are about seven
hours late. Subagent decision timestamps are not affected: each subagent took them with
`date -u`. The error was found at step S17 by comparing a subagent's `date -u` stamps with the
orchestrator's. From S17 on the orchestrator takes every timestamp with `date -u`, and
`docs/auto-run/tools/ledger.mjs` rejects any `at`, `started` or `finished` later than the current time.

**Corrected bounds.** The true values are bounded by git commit times (UTC), which the machine
clock wrote. For a run line, the step started no earlier than the previous step's judgement commit and
finished no later than its own artifact commit. For an orchestrator decision, it was taken no later than
the artifact commit it cites.

## Run log lines

| Step | Recorded started | Recorded finished | Started no earlier than | Finished no later than |
|------|------------------|-------------------|-------------------------|------------------------|
| S10 | 2026-10-18T00:03:00Z | 2026-10-18T00:22:45Z | 2026-10-17T17:30:39Z | 2026-10-17T17:51:44Z |
| S11 | 2026-10-18T00:45:00Z | 2026-10-18T01:21:40Z | 2026-10-17T17:51:49Z | 2026-10-17T18:29:41Z |
| S12 | 2026-10-18T01:23:30Z | 2026-10-18T02:14:30Z | 2026-10-17T18:29:46Z | 2026-10-17T19:22:22Z |
| S13 | 2026-10-18T02:22:00Z | 2026-10-18T02:55:00Z | 2026-10-17T19:22:27Z | 2026-10-17T19:57:00Z |
| S14 | 2026-10-18T03:08:00Z | 2026-10-18T03:52:00Z | 2026-10-17T19:57:06Z | 2026-10-17T20:41:50Z |
| S15 | 2026-10-18T03:55:00Z | 2026-10-18T04:40:00Z | 2026-10-17T20:41:56Z | 2026-10-17T21:25:21Z |
| S16 | 2026-10-18T04:42:00Z | 2026-10-18T05:25:30Z | 2026-10-17T21:25:27Z | 2026-10-17T22:19:58Z |

## Orchestrator decisions

| Decision | Step | Recorded at | Taken no later than |
|----------|------|-------------|---------------------|
| DEC-186 | S09 | 2026-10-18T00:01:30Z | 2026-10-17T17:30:34Z |
| DEC-187 | S09 | 2026-10-18T00:02:10Z | 2026-10-17T17:30:34Z |
| DEC-193 | S10 | 2026-10-18T00:43:20Z | 2026-10-17T17:51:44Z |
| DEC-234 | S12 | 2026-10-18T02:20:40Z | 2026-10-17T19:22:22Z |
| DEC-246 | S13 | 2026-10-18T03:05:10Z | 2026-10-17T19:57:00Z |
| DEC-310 | S16 | 2026-10-18T05:28:30Z | 2026-10-17T22:19:58Z |

## Earlier estimates

S00 and S01's run lines (started and finished) were estimated, not read from a clock, and are within a few minutes of their commits (b3e5c86, d392999). S02 to S09's run lines took `started` from `date -u` at dispatch and estimated `finished` from the subagent's reported duration; they agree with the commit times to within minutes.
