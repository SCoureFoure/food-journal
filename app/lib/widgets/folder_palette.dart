import 'package:flutter/material.dart';

/// The folder palette: one colour per tab, shared by the tab itself, the folder
/// body behind that tab's page, and the left spine on every panel the page
/// renders. One constant per tab is what keeps the three in agreement — a panel
/// must never reach for a theme colour directly.

/// Food Journal — the app's own green (`ColorScheme.fromSeed(0xFF42725C)`
/// secondary), the colour the journal's week panels have always used for their
/// spine. The tab was pulled up to match the panels rather than the other way
/// round: the deeper green reads as ink on the folder set, not as a pastel.
const Color kTabFoodJournal = Color(0xFF4D6357);

/// Meal Planning — the slate blue counterpart, echoing the green/blue pairing
/// on a real folder set.
const Color kTabMealPlanning = Color(0xFF93AFC6);

/// The manila the unselected tabs are mixed toward, so a deselected tab keeps
/// its identity while receding into the folder body.
const Color kFolderTabRecess = Color(0xFFDCCFB8);

/// The fill actually painted for a tab in the given state.
Color folderTabFill(Color base, {required bool selected}) =>
    folderTabFillAt(base, selected ? 1 : 0);

/// [folderTabFill] with the selection expressed as a 0..1 amount, so a tab can
/// be animated between the two states instead of snapping. `t == 1` returns
/// [base] itself and `t == 0` returns the fully recessed mix — the endpoints
/// are exact, not the result of a float lerp that lands a bit-off.
Color folderTabFillAt(Color base, double t) {
  if (t >= 1) return base;
  return Color.lerp(base, kFolderTabRecess, 0.55 * (1 - t))!;
}

/// Label ink for a tab, chosen against its own fill. Tab colours span from a
/// deep green to a pale slate, so a single hard-coded ink would be unreadable
/// on one end or the other.
Color folderTabInk(Color fill, {required bool selected}) {
  final onDark = ThemeData.estimateBrightnessForColor(fill) == Brightness.dark;
  if (onDark) {
    return selected ? const Color(0xFFF6F1E6) : const Color(0xFFE8E1D2);
  }
  return selected ? const Color(0xFF2E2A22) : const Color(0xFF6F6455);
}
