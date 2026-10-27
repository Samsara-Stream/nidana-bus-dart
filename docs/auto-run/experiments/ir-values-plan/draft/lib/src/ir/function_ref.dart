import 'package:meta/meta.dart';

/// A serializable reference to a transformer (Spec §6.5, Appendix A.4): a
/// name, or anonymous. It holds no function and is not a Function.
@immutable
final class FunctionRef {
  /// Throws ArgumentError for an empty [name].
  FunctionRef.named(String name) : name = _nonEmpty(name);
  const FunctionRef.anonymous() : name = null;

  /// The name the Dart VM renders for [function] (decides OQ-M1): the text
  /// between `from Function '` and the next `'` in function.toString(),
  /// anonymous when that text is absent or empty. Never calls [function].
  factory FunctionRef.of(Function function) {
    final String rendering = function.toString();
    final int marker = rendering.indexOf(_marker);
    if (marker < 0) {
      return const FunctionRef.anonymous();
    }
    final int start = marker + _marker.length;
    final int end = rendering.indexOf("'", start);
    if (end <= start) {
      return const FunctionRef.anonymous();
    }
    return FunctionRef.named(rendering.substring(start, end));
  }

  final String? name; // null when anonymous

  // name (topology-ir@v1 G7)
  @override
  bool operator ==(Object other) => other is FunctionRef && other.name == name;

  @override
  int get hashCode => name.hashCode;
}

// What precedes a function's name in the VM's rendering of it (G9).
const String _marker = "from Function '";

// [name] when it is not empty (G9).
String _nonEmpty(String name) => name.isEmpty
    ? throw ArgumentError.value(name, 'name', 'must not be empty')
    : name;
