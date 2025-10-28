import 'package:flutter/material.dart';
import '../pages/home/home_page.dart';
import '../pages/auth/login_page.dart';
import '../pages/auth/register_page.dart';
// import '../pages/profile/profile_page.dart';

class Routes {
  static const String home = '/home';
  static const String login = '/login';
  static const String register = '/register';
  static const String profile = '/profile';

  static Map<String, WidgetBuilder> getRoutes() {
    return {
      home: (context) => const HomePage(),
      login: (context) => const LoginPage(),
      register: (context) => const RegisterPage(),
      // profile: (context) => const ProfilePage(),
    };
  }
}
