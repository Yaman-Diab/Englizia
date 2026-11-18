import 'dart:ui' as ui;

import 'package:englizia/core/media/media_vault.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// A lesson's picture, from the phone when the lesson was downloaded and
/// from the network otherwise.
abstract final class KeptMedia {
  /// Set once at startup. Without it every picture comes from the network.
  static MediaVault vault = const NoMediaVault();

  static ImageProvider image(String url) =>
      vault.has(url) ? KeptImage(url, vault) : NetworkImage(url);
}

/// A picture the vault keeps, opened in memory only.
@immutable
final class KeptImage extends ImageProvider<KeptImage> {
  const KeptImage(this.url, this._vault);

  final String url;
  final MediaVault _vault;

  @override
  Future<KeptImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(KeptImage key, ImageDecoderCallback decode) =>
      MultiFrameImageStreamCompleter(
        codec: _load(decode),
        scale: 1,
        debugLabel: 'kept picture',
      );

  Future<ui.Codec> _load(ImageDecoderCallback decode) async {
    final bytes = await _vault.read(url);
    if (bytes == null) throw StateError('The picture is no longer kept');
    return decode(await ui.ImmutableBuffer.fromUint8List(bytes));
  }

  @override
  bool operator ==(Object other) => other is KeptImage && other.url == url;

  @override
  int get hashCode => url.hashCode;
}
