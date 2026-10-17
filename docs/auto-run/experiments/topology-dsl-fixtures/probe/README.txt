probe/codes.dart and probe/codes_main_only.dart were analyzed once, before
the reject fixtures were written, to learn which diagnostic code each
candidate misuse reports on the pinned SDK (Dart 3.13.5) and which lines
report more than one diagnostic. probe/codes.json is that run's
`fvm dart analyze --format=json` output.

Forms that report two diagnostics on one line, which a reject fixture cannot
mark (one marker names the next line only), and the single-diagnostic form
the fixtures use instead:
- a generic call whose function argument does not fit (P19, P22, P23) also
  reports inference_failure_on_function_invocation; the fixtures pass the
  type arguments explicitly (cart.map<String>(...)).
- a reduceInto whose reducer does not fit the inferred state type (P18)
  reports could_not_infer and argument_type_not_assignable; the fixtures pass
  <S, E> explicitly.
- two mismatched arguments on one line (P8); the fixtures put each argument on
  its own line.
- topology('x', body) without a scope (P40); the fixtures leave out the body
  instead (P39).
- a const TopologyRef(7) reports const_constructor_param_type_mismatch as
  well; the fixtures use a final declaration.
run.sh T4 and T5 confirm the codes the fixtures name.
