import 'package:flutter/material.dart';

import 'package:v2ray_box/v2ray_box.dart';

import 'pages/auth_page.dart';

import 'pages/vpn_page.dart';

import 'services/auth_storage.dart';

import 'theme/app_theme.dart';

import 'v2ray_instance.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  v2ray = V2rayBox();

  await v2ray.initialize(notificationStopButtonText: 'Отключить');

  await v2ray.setCoreEngine('xray');

  await v2ray.setServiceMode(VpnMode.vpn);

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String? _token;

  bool _checkingAuth = true;

  @override
  void initState() {
    super.initState();

    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final token = await AuthStorage.getToken();

    if (!mounted) return;

    setState(() {
      _token = token;

      _checkingAuth = false;
    });
  }

  void _onAuthenticated(String token) {
    setState(() => _token = token);
  }

  void _onLogout() {
    setState(() => _token = null);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      theme: AppTheme.dark,

      themeMode: ThemeMode.dark,

      home: _checkingAuth
          ? const _SplashScreen()
          : _token == null
          ? AuthPage(onAuthenticated: _onAuthenticated)
          : VpnPage(token: _token!, onLogout: _onLogout),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,

      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,

          children: [
            Container(
              width: 88,

              height: 88,

              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.15),

                borderRadius: BorderRadius.circular(26),
              ),

              child: const Icon(
                Icons.shield_outlined,

                size: 48,

                color: AppColors.accent,
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              'Shield VPN',

              style: TextStyle(
                fontSize: 24,

                fontWeight: FontWeight.bold,

                letterSpacing: -0.5,
              ),
            ),

            const SizedBox(height: 32),

            const SizedBox(
              width: 28,

              height: 28,

              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          ],
        ),
      ),
    );
  }
}
