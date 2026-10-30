/// An ordered log of calls shared between fakes, so a test can assert what
/// happened *before* what (for example "a check precedes every listen").
class CallLog {
  /// The entries, oldest first.
  final List<String> entries = [];

  /// Appends [entry].
  void add(String entry) => entries.add(entry);

  /// Entries that are, or start with, [prefix].
  List<String> where(String prefix) =>
      entries.where((e) => e.startsWith(prefix)).toList();
}
