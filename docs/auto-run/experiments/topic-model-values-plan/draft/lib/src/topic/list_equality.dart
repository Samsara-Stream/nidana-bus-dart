/// Whether [a] and [b] hold equal elements in the same order: the
/// element-wise comparison of parent correlation ids that envelope and
/// lineage equality use (topic-model@v1 G13). A List's own `==` is identity.
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
