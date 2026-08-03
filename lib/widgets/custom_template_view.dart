import 'dart:io';

import 'package:flutter/material.dart';

import '../models/custom_template.dart';
import 'looping_asset_video.dart';

class CustomTemplateView extends StatelessWidget {
  const CustomTemplateView({super.key, required this.template});

  final CustomTemplate template;

  @override
  Widget build(BuildContext context) {
    final media = template.media == CustomTemplateMedia.video
        ? LoopingAssetVideo(
            filePath: template.path,
            alignment: Alignment(template.alignX, template.alignY),
            scale: template.zoom,
          )
        : ClipRect(
            child: Transform.scale(
              scale: template.zoom,
              alignment: Alignment(template.alignX, template.alignY),
              child: Image.file(
                File(template.path),
                fit: BoxFit.cover,
                alignment: Alignment(template.alignX, template.alignY),
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          );
    return Opacity(opacity: template.opacity, child: media);
  }
}
