import 'package:flutter/material.dart';
import 'package:rephoto/theme/huashu_theme.dart';

abstract final class HuashuSnackBars {
  static SnackBar success(String message) {
    return SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: HuashuColors.positive,
      content: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: HuashuColors.surface,
            size: 20,
          ),
          const SizedBox(width: 10),
          Flexible(child: Text(message)),
        ],
      ),
    );
  }
}
