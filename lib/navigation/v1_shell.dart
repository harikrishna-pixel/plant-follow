import 'package:flutter/material.dart';

import '../view/screens/bottom_bar/bottom_bar.dart';

/// Navigation destinations for V1. Kept out of [V1Nav] to avoid an import cycle
/// with the bottom bar.
class V1Shell {
  static Widget restoreAfterPurchase() => const BottomNavExample();
}
