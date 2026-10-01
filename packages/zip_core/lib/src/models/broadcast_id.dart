import 'package:meta/meta.dart';

/// A validated 6-character Crockford-Base32 broadcast code (SR-02 §3).
///
/// [value] is always the canonical uppercase form, matching how codes are
/// generated and stored server-side. Crockford's alphabet excludes `I`, `L`,
/// `O`, `U` to avoid visual confusion with `1`/`0`. Parsing is
/// case-insensitive (so a viewer pasting the lowercase-displayed form still
/// resolves correctly against the case-sensitive server comparison) — but
/// display-casing (`k7m9x2`-style) is a presentation-only concern, never
/// stored on this value object.
@immutable
class BroadcastId {
  const BroadcastId._(this.value);

  /// Parses [input], throwing [FormatException] if it is not exactly 6
  /// Crockford-Base32 characters (case-insensitive).
  factory BroadcastId.parse(String input) {
    final id = BroadcastId.tryParse(input);
    if (id == null) {
      throw FormatException('Not a valid broadcast id: $input');
    }
    return id;
  }

  static const String _alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
  static const int _length = 6;

  /// The canonical, uppercase, validated code.
  final String value;

  /// Parses [input], returning `null` instead of throwing if it is not
  /// exactly 6 Crockford-Base32 characters (case-insensitive).
  static BroadcastId? tryParse(String input) {
    if (input.length != _length) return null;
    final upper = input.toUpperCase();
    for (final char in upper.codeUnits) {
      if (!_alphabet.codeUnits.contains(char)) return null;
    }
    return BroadcastId._(upper);
  }

  @override
  bool operator ==(Object other) =>
      other is BroadcastId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'BroadcastId($value)';
}
