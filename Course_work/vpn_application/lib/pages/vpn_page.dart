import 'package:flutter/material.dart';

import 'package:v2ray_box/v2ray_box.dart';

import '../services/api_service.dart';

import '../services/auth_storage.dart';

import '../subscription_service.dart';

import '../theme/app_theme.dart';

import '../v2ray_instance.dart';

import '../widgets/server_card.dart';

import '../widgets/server_picker_sheet.dart';

import '../widgets/vpn_power_button.dart';

class VpnPage extends StatefulWidget {
  const VpnPage({super.key, required this.token, required this.onLogout});

  final String token;

  final VoidCallback onLogout;

  @override
  State<VpnPage> createState() => _VpnPageState();
}

class _VpnPageState extends State<VpnPage> {
  final _api = ApiService();

  VpnStatus _status = VpnStatus.stopped;

  String _logs = '';

  bool _loadingSub = false;

  bool _pingLoading = false;

  bool _showLogs = false;

  String? _error;

  String? _username;

  int? _pingMs;

  List<VpnConfig> _configs = [];

  VpnConfig? _selectedConfig;

  @override
  void initState() {
    super.initState();

    v2ray.watchStatus().listen((status) {
      if (!mounted) return;

      setState(() => _status = status);
    });

    v2ray.watchLogs().listen((log) {
      if (!mounted) return;

      setState(() => _logs = log.toString());
    });

    _loadSubscription();
  }

  VpnUiStatus get _uiStatus {
    if (_error != null && _status == VpnStatus.stopped) {
      return VpnUiStatus.error;
    }

    return switch (_status) {
      VpnStatus.started => VpnUiStatus.connected,

      VpnStatus.starting => VpnUiStatus.connecting,

      _ => VpnUiStatus.disconnected,
    };
  }

  bool get _isConnected =>
      _status == VpnStatus.started || _status == VpnStatus.starting;

  Future<void> _loadSubscription() async {
    setState(() {
      _loadingSub = true;

      _error = null;
    });

    try {
      final profile = await _api.fetchProfile(widget.token);

      final subUrl = await _api.fetchSubscriptionUrl(widget.token);

      final links = await SubscriptionService.fetchConfigLinks(subUrl);

      if (links.isEmpty) {
        throw StateError('Подписка пуста или не содержит конфигов');
      }

      final configs = <VpnConfig>[];

      for (final link in links) {
        if (!v2ray.isValidConfigLink(link)) continue;

        configs.add(v2ray.parseConfigLink(link));
      }

      if (configs.isEmpty) {
        throw StateError('Не найдено валидных конфигов в подписке');
      }

      setState(() {
        _username = profile['username'] as String?;

        _configs = configs;

        _selectedConfig = configs.first;

        _pingMs = null;

        for (final c in _configs) {
          c.isSelected = c == _selectedConfig;
        }
      });
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        await AuthStorage.clearToken();

        if (mounted) widget.onLogout();

        return;
      }

      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loadingSub = false);
    }
  }

  Future<void> _connect() async {
    final config = _selectedConfig;

    if (config == null) {
      setState(() => _error = 'Сначала загрузите подписку');

      return;
    }

    setState(() => _error = null);

    try {
      final hasPermission = await v2ray.checkVpnPermission();

      if (!hasPermission) {
        final granted = await v2ray.requestVpnPermission();

        if (!granted) {
          setState(() => _error = 'Нужно разрешение VPN');

          return;
        }
      }

      final validationError = await v2ray.parseConfig(config.link);

      if (validationError.isNotEmpty) {
        setState(() => _error = 'Ошибка конфига: $validationError');

        return;
      }

      await v2ray.connect(config.link, name: config.name);
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _disconnect() async {
    await v2ray.disconnect();
  }

  Future<void> _toggleConnection() async {
    if (_isConnected) {
      await _disconnect();
    } else {
      await _connect();
    }
  }

  Future<void> _pingSelected() async {
    final config = _selectedConfig;

    if (config == null) return;

    setState(() => _pingLoading = true);

    try {
      final ms = await v2ray.ping(config.link);

      if (!mounted) return;

      setState(() => _pingMs = ms);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ping error: $e')));
    } finally {
      if (mounted) setState(() => _pingLoading = false);
    }
  }

  Future<void> _logout() async {
    await v2ray.disconnect();

    await AuthStorage.clearToken();

    widget.onLogout();
  }

  void _openServerPicker() {
    if (_configs.isEmpty || _isConnected) return;

    ServerPickerSheet.show(
      context,

      configs: _configs,

      selected: _selectedConfig,

      onSelect: (config) {
        setState(() {
          _selectedConfig = config;

          _pingMs = null;

          for (final c in _configs) {
            c.isSelected = c == config;
          }
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = _uiStatus;

    final statusColor = vpnStatusColor(status);

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onLongPress: () => setState(() => _showLogs = !_showLogs),

          child: const Text(AppBranding.name),
        ),

        actions: [
          IconButton(
            onPressed: _loadingSub ? null : _loadSubscription,

            icon: const Icon(Icons.refresh_rounded),

            tooltip: 'Обновить подписку',
          ),

          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),

            onSelected: (value) {
              if (value == 'logout') _logout();

              if (value == 'logs') setState(() => _showLogs = !_showLogs);
            },

            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'logs',

                child: Text(_showLogs ? 'Скрыть логи' : 'Показать логи'),
              ),

              const PopupMenuItem(value: 'logout', child: Text('Выйти')),
            ],
          ),
        ],
      ),

      body: _loadingSub && _configs.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),

              child: Column(
                children: [
                  if (_username != null) ...[
                    const SizedBox(height: 4),

                    Text(
                      _username!,

                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),

                        fontSize: 14,
                      ),
                    ),
                  ],

                  const Spacer(flex: 2),

                  VpnPowerButton(
                    status: status,

                    enabled: _selectedConfig != null,

                    onTap: _toggleConnection,
                  ),

                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,

                    children: [
                      Container(
                        width: 8,

                        height: 8,

                        decoration: BoxDecoration(
                          color: statusColor,

                          shape: BoxShape.circle,

                          boxShadow: status == VpnUiStatus.connected
                              ? [
                                  BoxShadow(
                                    color: statusColor.withValues(alpha: 0.6),

                                    blurRadius: 8,
                                  ),
                                ]
                              : null,
                        ),
                      ),

                      const SizedBox(width: 8),

                      Text(
                        vpnStatusLabel(status),

                        style: TextStyle(
                          fontSize: 18,

                          fontWeight: FontWeight.w600,

                          color: statusColor,
                        ),
                      ),
                    ],
                  ),

                  const Spacer(flex: 2),

                  if (_error != null) ...[
                    Container(
                      width: double.infinity,

                      padding: const EdgeInsets.all(12),

                      margin: const EdgeInsets.only(bottom: 12),

                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.12),

                        borderRadius: BorderRadius.circular(12),

                        border: Border.all(
                          color: AppColors.error.withValues(alpha: 0.3),
                        ),
                      ),

                      child: Text(
                        _error!,

                        style: const TextStyle(
                          color: AppColors.error,
                          fontSize: 13,
                        ),

                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],

                  if (_configs.isEmpty)
                    Column(
                      children: [
                        Icon(
                          Icons.cloud_off_outlined,

                          size: 48,

                          color: Colors.white.withValues(alpha: 0.3),
                        ),

                        const SizedBox(height: 12),

                        Text(
                          'Нет серверов',

                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ),

                        const SizedBox(height: 12),

                        OutlinedButton.icon(
                          onPressed: _loadSubscription,

                          icon: const Icon(Icons.refresh),

                          label: const Text('Обновить'),
                        ),
                      ],
                    )
                  else if (_selectedConfig != null)
                    ServerCard(
                      name: _selectedConfig!.name,

                      protocol: _selectedConfig!.protocolDisplayName,

                      pingMs: _pingMs,

                      pingLoading: _pingLoading,

                      onTap: _isConnected ? null : _openServerPicker,

                      onPing: _pingSelected,
                    ),

                  if (_showLogs) ...[
                    const SizedBox(height: 12),

                    SizedBox(
                      height: 100,

                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.surface,

                          borderRadius: BorderRadius.circular(12),

                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),

                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(8),

                          child: Text(
                            _logs.isEmpty ? 'Логи...' : _logs,

                            style: TextStyle(
                              fontSize: 11,

                              fontFamily: 'monospace',

                              color: Colors.white.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}
