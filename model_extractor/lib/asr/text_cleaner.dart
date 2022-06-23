/// Text cleaner utility
class TextCleaner {
  final nonAlphaRegEx = RegExp(r'[^\w\d]');
  final alphaRegEx = RegExp(r'[\w\d]');

  /// Normalize input text to lowercase and remove non-alphanumeric characters.
  Iterable<String> normalize(String word) sync* {
    final normalisedWithCap = word.replaceAll(nonAlphaRegEx, '');
    var normalised = normalisedWithCap.toLowerCase();
    yield normalised;
  }
}
