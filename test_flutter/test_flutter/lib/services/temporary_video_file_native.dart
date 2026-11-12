import 'dart:io';
import 'package:camera/camera.dart';

Future<void> deleteTemporaryVideo(XFile file) async {
  final local = File(file.path);
  if (await local.exists()) await local.delete();
}
