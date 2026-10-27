/// The element-wise comparison that value equality uses for the lists a
/// value holds: an envelope's and a lineage's parent correlation ids
/// (topic-model@v1 G13), and the lists and sets of the IR values, findings,
/// claims and graphs (topology-ir@v1 G7), a set compared as its list: true
/// when [a] and [b] have the same length and `a[i] == b[i]` at every index.
/// A `List`'s own `==` is identity.
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
