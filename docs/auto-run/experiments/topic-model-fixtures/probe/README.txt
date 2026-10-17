probe/codes.dart was analyzed once, before the fixtures were written, to learn
which diagnostic code each candidate misuse reports on the pinned SDK and which
lines report more than one diagnostic (a const declaration missing an argument
reports three; an uninstantiated generic call adds an inference warning).
probe/codes.json is that run's `fvm dart analyze --format=json` output. The
reject fixtures avoid every multi-diagnostic form; run.sh T4 and T5 confirm the
codes the fixtures name.
