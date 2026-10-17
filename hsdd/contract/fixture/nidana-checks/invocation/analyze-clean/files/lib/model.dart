final class AuthToken {
  const AuthToken(this.value);
  final String value;
  static const AuthToken none = AuthToken('');
}

final class SearchResults {
  const SearchResults(this.items);
  final List<String> items;
  static const SearchResults empty = SearchResults(<String>[]);
}
