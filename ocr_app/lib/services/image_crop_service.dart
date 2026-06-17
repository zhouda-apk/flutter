import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';

import '../theme/app_theme.dart';

class ImageCropService {
  Future<String?> cropForOcr(
    BuildContext context,
    String imagePath,
  ) async {
    final cropped = await ImageCropper().cropImage(
      sourcePath: imagePath,
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 96,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: '裁切文件',
          toolbarColor: AppColors.primary,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: false,
          aspectRatioPresets: const [
            CropAspectRatioPreset.original,
            CropAspectRatioPreset.ratio3x2,
            CropAspectRatioPreset.ratio4x3,
            CropAspectRatioPreset.ratio5x4,
          ],
        ),
        IOSUiSettings(
          title: '裁切文件',
          doneButtonTitle: '完成',
          cancelButtonTitle: '取消',
          aspectRatioPresets: const [
            CropAspectRatioPreset.original,
            CropAspectRatioPreset.ratio3x2,
            CropAspectRatioPreset.ratio4x3,
            CropAspectRatioPreset.ratio5x4,
          ],
        ),
        WebUiSettings(
          context: context,
          presentStyle: WebPresentStyle.dialog,
          size: const CropperSize(width: 520, height: 720),
        ),
      ],
    );

    return cropped?.path;
  }
}
