import 'package:englizia/core/video/video_engine.dart';
import 'package:englizia/features/lessons/domain/entities/lesson_video.dart';

enum VideoStage { cover, playing, failed }

/// What a lesson's player shows, whichever lesson it plays in.
abstract interface class PlayerState {
  String? get lessonTitle;
  LessonVideo? get video;
  VideoStage get stage;

  /// Where the learner stopped last time: «توقفت عند 2:14», until they choose.
  Duration? get resumeFrom;
  Duration get position;
  Duration get duration;
  Duration get bufferedTo;
  bool get playing;
  bool get buffering;

  /// Still loading after a while: a lower quality is offered.
  bool get slowConnection;
  bool get captions;
  String? get caption;
  double get speed;
  VideoQuality get quality;
}

/// What pressing the player's buttons asks of its lesson.
abstract interface class PlayerActions {
  /// For the picture; the cubit only tells it what to do.
  VideoEngine get engine;

  /// What the speed's sheet offers.
  List<double> get speeds;

  Future<void> play();

  Future<void> playFromStart();

  Future<void> togglePlay();

  Future<void> seekTo(Duration position);

  Future<void> skipBack();

  Future<void> skipForward();

  void toggleCaptions();

  Future<void> setSpeed(double speed);

  Future<void> setQuality(VideoQuality quality);

  Future<void> lowerQuality();

  Future<void> retry();
}
