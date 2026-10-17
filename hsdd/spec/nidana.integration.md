# nidana.integration: Integration

- **Kind:** leaf-parent
- **Purpose:** prove the children compose: replay contract fixtures against live components and run end-to-end slices of the primary flows in an example Flutter app
- **Owns:**
  - workspace member `nidana_integration`, not published, holding the example Flutter app and its tests (ADR-002)
  - live replays of every contract's fixtures against the composed packages (ADR-001)
  - end-to-end slices of the primary flows:
    - bootstrap: `APPLICATION` topologies activated in any order, service publishers claiming their state topics, observers registered, a deep-link intent published before `start()` and delivered after it (Spec §3.13, §11.2, Guide §3.5)
    - hydration: an example persistence service publishing a loaded value as an event, a reducer topology folding it into a state topic with an `Initializing` variant, the UI rendering the transition (Spec §2.5, §7.6)
    - single-writer ownership: a second claimant rejected at activation and at publisher construction (Spec §3.11)
    - module scope: in-subtree navigation that keeps the module's topologies alive through the grace period, exit that tears them down, re-entry that resumes retained state (Spec §7.2 to §7.4)
    - guarded navigation: an unauthenticated intent redirected to login, a resolved intent executed, `nav.current-route` and `nav.history` written together (Guide §3.4)
    - observation: a non-sensitive observer that never sees a sensitive topic and a sensitive-capable one that does, with redaction in the recorder (Spec §9)
    - CI: the codegen and the v1 checks run over the example, pass, and fail on seeded violations (Guide §5.2)
- **Does not own:** any package's behavior; fixes for what it finds, which go back to the owning node
- **Consumes:** [topic-model@v1, topology-dsl@v1, topology-ir@v1, bus-api@v1, bus-testing@v1, navigation-api@v1, flutter-binding@v1, topic-codegen@v1, nidana-checks@v1]
- **Produces:** none
- **Governed by:** [ADR-001, ADR-002, ADR-003]
- **Sources:**
  - `ref/nidana-docs/arch/nidana-bus-ref-arch-spec-v0_15_0.md` §2.5, §3.11, §3.13, §7.2 to §7.6, §9, §11.2
  - `ref/nidana-docs/arch/nidana-bus-ref-arch-guide-v0_15_0.md` §3.4, §3.5, §5.2, Appendix A
  - `ref/nidana-docs/arch/nidana-bus-ref-arch-rationale-v0_15_0.md` §3.1
- **Decomposes into:** phases (see hsdd-phase-plan)
- **Isolation strategy:** none by design: `hard` edges to every producing sibling, so the DAG schedules it after they ship; its phases default to full-review

## Overview

Every other node is tested against contracts; none of them exercises two live siblings together. This node does, using Guide Appendix A's full system diagram as the reference scenario for the example app. Its tests run as widget tests under `testWidgets` with the production scheduler provider (ADR-003), and as VM tests on `TestBus` where no widget is involved.

A failure found here is a finding against the owning node or contract, recorded in the phase's verification doc; this node never patches another node's package.
