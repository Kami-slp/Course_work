import 'package:flutter/material.dart';
import 'package:v2ray_box/v2ray_box.dart';

import 'pages/auth_page.dart';
import 'pages/vpn_page.dart';
import 'services/auth_storage.dart';
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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6C5CE7)),
        useMaterial3: true,
      ),
      home: _checkingAuth
          ? const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            )
          : _token == null
              ? AuthPage(onAuthenticated: _onAuthenticated)
              : VpnPage(token: _token!, onLogout: _onLogout),
    );
  }
}
