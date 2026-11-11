import 'package:equatable/equatable.dart';

/// A release number as the stores show it: "1.4.2". A build number ("+12")
/// or a pre-release tag ("-beta") is ignored, and a missing part counts as 0.
final class AppVersion extends Equatable implements Comparable<AppVersion> {
  const AppVersion(this.major, [this.minor = 0, this.patch = 0]);

  final int major;
  final int minor;
  final int patch;

  static final _part = RegExp(r'^\d{1,9}$');

  /// Null for anything that isn't a release number.
  static AppVersion? tryParse(String? text) {
    if (text == null) return null;
    final parts = text.trim().split(RegExp('[+-]')).first.split('.');
    if (parts.length > 3 || !parts.every(_part.hasMatch)) return null;
    final numbers = parts.map(int.parse).toList();
    return AppVersion(
      numbers[0],
      numbers.elementAtOrNull(1) ?? 0,
      numbers.elementAtOrNull(2) ?? 0,
    );
  }

  bool operator <(AppVersion other) => compareTo(other) < 0;

  @override
  int compareTo(AppVersion other) => switch (major.compareTo(other.major)) {
    0 => switch (minor.compareTo(other.minor)) {
      0 => patch.compareTo(other.patch),
      final order => order,
    },
    final order => order,
  };

  @override
  List<Object?> get props => [major, minor, patch];

  @override
  String toString() => '$major.$minor.$patch';
}
