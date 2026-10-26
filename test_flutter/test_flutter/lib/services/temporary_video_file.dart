import 'package:camera/camera.dart';
import 'temporary_video_file_unsupported.dart'
    if (dart.library.io) 'temporary_video_file_native.dart' as platform;

Future<void> deleteTemporaryVideo(XFile file) => platform.deleteTemporaryVideo(file);
