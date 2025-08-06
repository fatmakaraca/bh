import 'package:btk_demo/views/ana_sayfa/ana_sayfa.dart';
import 'package:btk_demo/views/app_view.dart';
import 'package:btk_demo/views/chat_view/chat_view.dart';
import 'package:btk_demo/views/auth_view/auth_view.dart';
import 'package:btk_demo/views/bakilan_hastalar_view.dart';
import 'package:btk_demo/views/source_view.dart';
import 'package:btk_demo/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

final _routerKey = GlobalKey<NavigatorState>();

class AppRoutes {
  AppRoutes._();
  static const String auth = '/';
  static const String anasayfa = '/anasayfa';
  static const String chatscreen = '/chatscreen';
  static const String bakilanHastalar = '/bakilan-hastalar';
  static const String source = '/source';
}

final router = GoRouter(
  navigatorKey: _routerKey,
  initialLocation: AppRoutes.auth,
  redirect: (context, state) async {
    // Kullanıcı durumunu kontrol et
    final user = await AuthService.getCurrentUser();
    final isAuthRoute = state.matchedLocation == AppRoutes.auth;

    // Eğer kullanıcı giriş yapmışsa ve auth sayfasındaysa ana sayfaya yönlendir
    if (user != null && isAuthRoute) {
      return AppRoutes.anasayfa;
    }

    // Eğer kullanıcı giriş yapmamışsa ve auth sayfasında değilse auth sayfasına yönlendir
    if (user == null && !isAuthRoute) {
      return AppRoutes.auth;
    }

    // Diğer durumlarda yönlendirme yapma
    return null;
  },
  routes: [
    // Auth ekranı
    GoRoute(
      path: AppRoutes.auth,
      builder: (context, state) => const AuthView(),
    ),

    // Ana uygulama (giriş yapıldıktan sonra)
    StatefulShellRoute.indexedStack(
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.anasayfa,
              builder: (context, state) => const HomeScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.bakilanHastalar,
              builder: (context, state) => const BakilanHastalarView(),
            ),
          ],
        ),
      ],
      builder: (context, state, navigationShell) =>
          AppView(navigationShell: navigationShell),
    ),

    // Chat ekranı (modal)
    GoRoute(
      path: AppRoutes.chatscreen,
      builder: (context, state) {
        final area = state.uri.queryParameters['area'];
        final doctorGender = state.uri.queryParameters['doctor_gender'];
                     return ChatView(area: area, doctorGender: doctorGender);
      },
    ),

    // Source ekranı (modal)
    GoRoute(
      path: AppRoutes.source,
      builder: (context, state) {
        final area = state.uri.queryParameters['area'];
        final correctDiagnosis = state.uri.queryParameters['correct_diagnosis'];
        return SourceView(area: area, correctDiagnosis: correctDiagnosis);
      },
    ),
  ],
);
