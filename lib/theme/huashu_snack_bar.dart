import 'package:flutter/material.dart';
import 'package:rephoto/theme/huashu_theme.dart';

abstract final class HuashuSnackBars {
  static SnackBar success(BuildContext context, String message) {
    return SnackBar(
      behavior: SnackBarBehavior.floating,
      margin: _topMargin(context),
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

  static SnackBar message(BuildContext context, String message) {
    return SnackBar(
      behavior: SnackBarBehavior.floating,
      margin: _topMargin(context),
      content: Text(message),
    );
  }

  static EdgeInsets _topMargin(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final top = mediaQuery.padding.top + 16;
    final bottom = (mediaQuery.size.height - top - 72).clamp(
      0.0,
      double.infinity,
    );
    return EdgeInsets.fromLTRB(20, top, 20, bottom);
  }
}
