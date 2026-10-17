codes.dart: the candidate type-level misuses of bus-api@v1, analyzed against
the stand-in once, before the reject fixtures were written, to learn the
code each reports. codes.txt is that run (line severity code | message).
Two lessons went into the fixtures: an `implements` of a final class needs
`abstract` to avoid a second diagnostic on the line, and an explicit type
argument avoids the strict-inference warning a variant mismatch adds.
Assigning a getter reports assignment_to_final for a final field and
assignment_to_final_no_setter for a getter without one, so the immutability
reject is pinned to BusConfig, whose fields the const constructor makes
final. Run from the experiment root:
  fvm dart analyze --format=json probe/codes.dart
