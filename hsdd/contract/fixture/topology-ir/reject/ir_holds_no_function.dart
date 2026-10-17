// Reject fixture for topology-ir@v1 G4: the IR holds no function (Spec §6.5,
// Appendix A.4). A function reference is not a function, cannot be called,
// and exposes no function; an edge exposes none either.
// covers: G4
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';

void takes(Function f) {}

void misuse(FunctionRef ref, TransformEdge edge) {
  // expect-diagnostic: argument_type_not_assignable
  takes(ref);
  // expect-diagnostic: invocation_of_non_function_expression
  ref();
  // expect-diagnostic: undefined_getter
  takes(ref.function);
  // expect-diagnostic: undefined_getter
  takes(edge.function);
  // expect-diagnostic: argument_type_not_assignable
  takes(edge.transformer!);
}
