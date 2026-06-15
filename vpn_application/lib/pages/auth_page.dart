import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/auth_storage.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key, required this.onAuthenticated});

  final ValueChanged<String> onAuthenticated;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _api = ApiService();

  final _apiUrlController = TextEditingController();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    AuthStorage.getApiBaseUrl().then((url) {
      if (mounted) _apiUrlController.text = url;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _apiUrlController.dispose();
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitLogin() async {
    await _submit(isRegister: false);
  }

  Future<void> _submitRegister() async {
    await _submit(isRegister: true);
  }

  Future<void> _submit({required bool isRegister}) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await AuthStorage.saveApiBaseUrl(_apiUrlController.text.trim());

      final email = _emailController.text.trim();
      final password = _passwordController.text;

      final token = isRegister
          ? await _api.register(
              email: email,
              username: _usernameController.text.trim(),
              password: password,
            )
          : await _api.login(email: email, password: password);

      await AuthStorage.saveToken(token);
      if (!mounted) return;
      widget.onAuthenticated(token);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('VPN'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Вход'),
            Tab(text: 'Регистрация'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildForm(onSubmit: _submitLogin, showUsername: false),
          _buildForm(onSubmit: _submitRegister, showUsername: true),
        ],
      ),
    );
  }

  Widget _buildForm({
    required VoidCallback onSubmit,
    required bool showUsername,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _apiUrlController,
            decoration: const InputDecoration(
              labelText: 'URL бэкенда',
              border: OutlineInputBorder(),
              hintText: 'http://192.168.0.104:8000',
              helperText: 'Телефон: IP ПК в Wi‑Fi. Эмулятор: http://10.0.2.2:8000',
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _loading
                ? null
                : () {
                    _apiUrlController.text = AuthStorage.defaultApiBaseUrl;
                  },
            icon: const Icon(Icons.wifi, size: 18),
            label: const Text('Подставить IP этого ПК'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
            ),
          ),
          if (showUsername) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'Username',
                border: OutlineInputBorder(),
                helperText: 'Только латиница, цифры и _',
              ),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Пароль',
              border: OutlineInputBorder(),
              helperText: 'Минимум 6 символов',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _loading ? null : onSubmit,
            child: _loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(showUsername ? 'Зарегистрироваться' : 'Войти'),
          ),
        ],
      ),
    );
  }
}
