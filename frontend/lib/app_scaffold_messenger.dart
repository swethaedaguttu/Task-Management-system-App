import 'dart:async';

import 'package:flutter/material.dart';

/// Root messenger so messages still show after [Navigator.push] + async work.
final GlobalKey<ScaffoldMessengerState> appMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

Timer? _appBannerTimer;

/// Shows a short message at the **top** of the screen (below the status bar /
/// app bar) using [MaterialBanner], not a bottom [SnackBar].
void showAppSnackBar(String message, {bool isError = false}) {
  _appBannerTimer?.cancel();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final ms = appMessengerKey.currentState;
    if (ms == null) return;
    ms.clearSnackBars();
    ms.clearMaterialBanners();
    ms.showMaterialBanner(
      MaterialBanner(
        leading: Icon(
          isError ? Icons.error_outline : Icons.check_circle_outline,
          color: isError ? null : Colors.green,
        ),
        content: Text(message),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Dismiss',
            onPressed: () {
              _appBannerTimer?.cancel();
              ms.hideCurrentMaterialBanner();
            },
          ),
        ],
      ),
    );
    _appBannerTimer = Timer(const Duration(seconds: 3), () {
      ms.hideCurrentMaterialBanner();
    });
  });
}
