import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Navigation state for managing tab transitions
class NavigationState {
  final int currentTabIndex;
  final int previousTabIndex;

  const NavigationState({
    this.currentTabIndex = 0,
    this.previousTabIndex = 0,
  });

  /// Returns slide direction: 1.0 for right-to-left, -1.0 for left-to-right
  double get slideDirection {
    if (currentTabIndex > previousTabIndex) {
      return 1.0; // New tab is to the right, slide from right
    } else if (currentTabIndex < previousTabIndex) {
      return -1.0; // New tab is to the left, slide from left
    }
    return 0.0; // Same tab, no slide
  }

  NavigationState copyWith({
    int? currentTabIndex,
    int? previousTabIndex,
  }) {
    return NavigationState(
      currentTabIndex: currentTabIndex ?? this.currentTabIndex,
      previousTabIndex: previousTabIndex ?? this.previousTabIndex,
    );
  }
}

/// Navigation state notifier for managing tab transitions
class NavigationNotifier extends StateNotifier<NavigationState> {
  NavigationNotifier() : super(const NavigationState());

  /// Navigate to a new tab, tracking the previous tab for animation direction
  void navigateToTab(int newIndex) {
    if (newIndex != state.currentTabIndex) {
      state = NavigationState(
        currentTabIndex: newIndex,
        previousTabIndex: state.currentTabIndex,
      );
    }
  }

  /// Set initial tab without animation
  void setInitialTab(int index) {
    state = NavigationState(
      currentTabIndex: index,
      previousTabIndex: index,
    );
  }
}

/// Provider for navigation state
final navigationProvider =
    StateNotifierProvider<NavigationNotifier, NavigationState>((ref) {
  return NavigationNotifier();
});

/// Tab index constants for the bottom navigation
class NavTabs {
  static const int ivStatus = 0;
  static const int notifications = 1;
  static const int account = 2;

  /// Get route path for tab index
  static String getRoutePath(int index) {
    switch (index) {
      case ivStatus:
        return '/iv-status';
      case notifications:
        return '/notifications';
      case account:
        return '/account';
      default:
        return '/iv-status';
    }
  }

  /// Get tab index for route path
  static int getTabIndex(String path) {
    if (path.contains('/iv-status') || path.contains('/iv-dashboard')) return ivStatus;
    if (path.contains('/notifications')) return notifications;
    if (path.contains('/account')) return account;
    return ivStatus;
  }
}
