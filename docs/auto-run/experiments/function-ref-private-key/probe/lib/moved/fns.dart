// The library whose names the probe renders. lib/moved/fns.dart is the same
// text at another URL.

int _hidden(int x) => x;
int shown(int x) => x;

final class _Holder {
  const _Holder();
  const _Holder.named();
  const _Holder._secret();
  int _method(int x) => x;
  int method(int x) => x;
  static int _staticHidden(int x) => x;
}

final class Holder {
  const Holder._internal(this.v);
  final int v;
  static int _staticOfPublic(int x) => x;
  int _format(int x) => x;
}

/// Every probe function, by label, in print order.
Map<String, Function> probeFunctions() => <String, Function>{
      'private top-level _hidden': _hidden,
      'public top-level shown': shown,
      'private method _Holder._method': const _Holder()._method,
      'public method _Holder.method': const _Holder().method,
      'private static _Holder._staticHidden': _Holder._staticHidden,
      'private static Holder._staticOfPublic': Holder._staticOfPublic,
      'private method of a public class Holder._format': const Holder._internal(1)._format,
      'private constructor Holder._internal': Holder._internal,
      'private class constructor _Holder.new': _Holder.new,
      'private class constructor _Holder.named': _Holder.named,
      'private class constructor _Holder._secret': _Holder._secret,
    };
