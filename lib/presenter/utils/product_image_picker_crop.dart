import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

/// Seleciona imagem e abre o crop em proporção **4:3** (mesma área do detalhe).
Future<String?> pickAndCropProductPhoto(ImageSource source) async {
  final picker = ImagePicker();
  final picked = await picker.pickImage(
    source: source,
    imageQuality: 92,
  );
  if (picked == null) return null;

  final cropped = await ImageCropper().cropImage(
    sourcePath: picked.path,
    aspectRatio: const CropAspectRatio(ratioX: 4, ratioY: 3),
    compressFormat: ImageCompressFormat.jpg,
    compressQuality: 90,
    uiSettings: [
      AndroidUiSettings(
        toolbarTitle: 'Ajustar foto',
        lockAspectRatio: true,
        toolbarColor: Colors.grey.shade900,
        toolbarWidgetColor: Colors.white,
        activeControlsWidgetColor: Colors.lightBlueAccent,
      ),
      IOSUiSettings(
        title: 'Ajustar foto',
        aspectRatioLockEnabled: true,
      ),
    ],
  );

  return cropped?.path;
}
