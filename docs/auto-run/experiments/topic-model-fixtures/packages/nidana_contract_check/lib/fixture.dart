/// Stand-in for `package:nidana_contract_check/fixture.dart` (ADR-001 item 4).
library;

/// One conformance case: a name beginning with its guarantee id, and a body
/// that runs against the harness an implementation supplies.
typedef ConformanceCase<H> = ({String name, Future<void> Function(H harness) body});
