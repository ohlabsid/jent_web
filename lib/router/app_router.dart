import 'package:go_router/go_router.dart';
import 'package:jent_web/features/desktop/view/home_page.dart';
import 'package:jent_web/features/ignite/view/ignite_page.dart';
import 'package:jent_web/router/app_path.dart';
import 'package:flutter/material.dart';

class AppRouter {
  static final router = GoRouter(
    initialLocation: AppPath.ignite,
    routerNeglect: true,
    routes: [
      GoRoute(
        path: AppPath.ignite,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const IgnitePage(),
          transitionsBuilder: (
            context,
            animation,
            secondaryAnimation,
            child,
          ) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          transitionDuration: const Duration(
            seconds: 4,
          ),
        ),
      ),

      GoRoute(
        path: AppPath.home,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const HomePage(),
          transitionsBuilder: (
            context,
            animation,
            secondaryAnimation,
            child,
          ) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          transitionDuration: const Duration(
            seconds: 2
          ),
        ),
      ),
    ],
  );
}
