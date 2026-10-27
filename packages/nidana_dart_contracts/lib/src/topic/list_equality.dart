/// The element-wise comparison of parent correlation ids that envelope and
/// lineage equality use (G13): true when [a] and [b] have the same length and
/// `a[i] == b[i]` at every index. A `List`'s own `==` is identity.
bool elementsEqual(List<Object?> a, List<Object?> b) {
  if (a.length != b.length) {
    return false;
  }
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}
