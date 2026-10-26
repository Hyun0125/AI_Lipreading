import 'package:video_player/video_player.dart';
import 'recorded_video_player_unsupported.dart'
    if (dart.library.io) 'recorded_video_player_native.dart'
    if (dart.library.js_interop) 'recorded_video_player_web.dart' as platform;

VideoPlayerController createRecordedVideoController(String path) =>
    platform.createRecordedVideoController(path);
