import 'package:flutter/material.dart';

import '../services/api_service.dart';

import '../services/auth_storage.dart';

import '../theme/app_theme.dart';

import '../widgets/auth_text_field.dart';

import '../widgets/server_settings_sheet.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key, required this.onAuthenticated});

  final ValueChanged<String> onAuthenticated;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _api = ApiService();

  final _emailController = TextEditingController();

  final _usernameController = TextEditingController();

  final _passwordController = TextEditingController();

  bool _loading = false;

  bool _isRegister = false;

  String? _error;

  @override
  void dispose() {
    _emailController.dispose();

    _usernameController.dispose();

    _passwordController.dispose();

    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;

      _error = null;
    });

    try {
      final email = _emailController.text.trim();

      final password = _passwordController.text;

      final token = _isRegister
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,

            children: [
              Align(
                alignment: Alignment.centerRight,

                child: IconButton(
                  onPressed: () => ServerSettingsSheet.show(context),

                  icon: const Icon(Icons.settings_outlined),

                  tooltip: 'Настройки сервера',
                ),
              ),

              const SizedBox(height: 8),

              Container(
                width: 80,

                height: 80,

                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),

                  borderRadius: BorderRadius.circular(24),
                ),

                child: const Icon(
                  Icons.shield_outlined,

                  size: 44,

                  color: AppColors.accent,
                ),
              ),

              const SizedBox(height: 24),

              const Text(
                'Shield VPN',

                style: TextStyle(
                  fontSize: 28,

                  fontWeight: FontWeight.bold,

                  letterSpacing: -0.5,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                'Безопасное подключение',

                style: TextStyle(
                  fontSize: 15,

                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),

              const SizedBox(height: 32),

              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Вход')),

                  ButtonSegment(value: true, label: Text('Регистрация')),
                ],

                selected: {_isRegister},

                onSelectionChanged: (value) {
                  setState(() {
                    _isRegister = value.first;

                    _error = null;
                  });
                },
              ),

              const SizedBox(height: 24),

              AuthTextField(
                controller: _emailController,

                label: 'Email',

                icon: Icons.email_outlined,

                keyboardType: TextInputType.emailAddress,
              ),

              if (_isRegister) ...[
                const SizedBox(height: 14),

                AuthTextField(
                  controller: _usernameController,

                  label: 'Username',

                  icon: Icons.person_outline,

                  helperText: 'Только латиница, цифры и _',
                ),
              ],

              const SizedBox(height: 14),

              AuthTextField(
                controller: _passwordController,

                label: 'Пароль',

                icon: Icons.lock_outline,

                obscureText: true,

                helperText: 'Минимум 6 символов',
              ),

              if (_error != null) ...[
                const SizedBox(height: 16),

                Container(
                  padding: const EdgeInsets.all(12),

                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.12),

                    borderRadius: BorderRadius.circular(12),

                    border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.3),
                    ),
                  ),

                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: AppColors.error,
                        size: 20,
                      ),

                      const SizedBox(width: 10),

                      Expanded(
                        child: Text(
                          _error!,

                          style: const TextStyle(
                            color: AppColors.error,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              FilledButton(
                onPressed: _loading ? null : _submit,

                child: _loading
                    ? const SizedBox(
                        width: 22,

                        height: 22,

                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_isRegister ? 'Зарегистрироваться' : 'Войти'),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
