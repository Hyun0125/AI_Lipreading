import 'package:video_player/video_player.dart';

// camera_web가 반환하는 blob: URL은 video_player_web에서 네트워크 URL로 재생한다.
VideoPlayerController createRecordedVideoController(String path) =>
    VideoPlayerController.networkUrl(Uri.parse(path));
