import 'package:flutter/material.dart';

final ValueNotifier<String?> currentRouteNotifier = ValueNotifier<String?>('/');

class AppRouteObserver extends RouteObserver<PageRoute<dynamic>> {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (route is PageRoute) {
      currentRouteNotifier.value = route.settings.name;
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (previousRoute is PageRoute) {
      currentRouteNotifier.value = previousRoute.settings.name;
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute is PageRoute) {
      currentRouteNotifier.value = newRoute.settings.name;
    }
  }
}

final AppRouteObserver routeObserver = AppRouteObserver();
