import 'package:meta/meta.dart';

/// A serializable reference to a transformer (Spec §6.5, Appendix A.4): a
/// name, or anonymous. It holds no function and is not a Function.
@immutable
final class FunctionRef {
  /// Throws ArgumentError for an empty [name].
  FunctionRef.named(String this.name);
  const FunctionRef.anonymous() : name = null;

  /// The name the Dart VM renders for [function] (decides OQ-M1): the text
  /// between `from Function '` and the next `'` in function.toString(),
  /// anonymous when that text is absent or empty. Never calls [function].
  factory FunctionRef.of(Function function) => throw UnimplementedError();

  final String? name; // null when anonymous
}
