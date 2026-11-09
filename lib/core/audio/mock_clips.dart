/// Mock mode's clips (`env/mock.json`): the mock's data links to
/// `example.com`, and each link plays the file `tool/sounds/mock_clips.py`
/// spoke for it, named by the same rule. Mock data only (STATUS D-050).
abstract final class MockClips {
  static const folder = 'assets/mock/audio';

  static final _mockLink = RegExp(r'^https://(cdn\.)?example\.com/.+\.mp3$');

  /// The bundled file for [url], or null when it isn't one of the mock's.
  static String? assetFor(String url) {
    if (!_mockLink.hasMatch(url)) return null;
    final name = url
        .toLowerCase()
        .replaceFirst(RegExp('^[a-z]+://'), '')
        .replaceFirst(RegExp(r'\.[a-z0-9]+$'), '')
        .replaceAll(RegExp('[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return '$folder/$name.wav';
  }
}
