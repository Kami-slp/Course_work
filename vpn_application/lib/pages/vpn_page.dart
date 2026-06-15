import 'package:flutter/material.dart';
import 'package:v2ray_box/v2ray_box.dart';

import '../services/api_service.dart';
import '../services/auth_storage.dart';
import '../subscription_service.dart';
import '../v2ray_instance.dart';

class VpnPage extends StatefulWidget {
  const VpnPage({
    super.key,
    required this.token,
    required this.onLogout,
  });

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
  String? _error;
  String? _username;

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

  Future<void> _pingSelected() async {
    final config = _selectedConfig;
    if (config == null) return;
    try {
      final ms = await v2ray.ping(config.link);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ping ${config.name}: ${ms}ms')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ping error: $e')),
      );
    }
  }

  Future<void> _logout() async {
    await v2ray.disconnect();
    await AuthStorage.clearToken();
    widget.onLogout();
  }

  bool get _isConnected =>
      _status == VpnStatus.started || _status == VpnStatus.starting;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_username != null ? 'VPN · $_username' : 'VPN'),
        actions: [
          IconButton(
            onPressed: _loadingSub ? null : _loadSubscription,
            icon: const Icon(Icons.refresh),
            tooltip: 'Обновить подписку',
          ),
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            tooltip: 'Выйти',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Статус: $_status',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 12),
            Expanded(
              child: _configs.isEmpty
                  ? Center(
                      child: _loadingSub
                          ? const CircularProgressIndicator()
                          : const Text('Нет конфигов. Нажмите обновить.'),
                    )
                  : ListView.builder(
                      itemCount: _configs.length,
                      itemBuilder: (context, index) {
                        final config = _configs[index];
                        final selected = config == _selectedConfig;
                        return Card(
                          color: selected
                              ? Theme.of(context)
                                  .colorScheme
                                  .primaryContainer
                                  .withValues(alpha: 0.5)
                              : null,
                          child: ListTile(
                            title: Text(config.name),
                            subtitle: Text(config.protocolDisplayName),
                            trailing: selected
                                ? const Icon(Icons.check_circle)
                                : null,
                            onTap: () {
                              setState(() {
                                _selectedConfig = config;
                                for (final c in _configs) {
                                  c.isSelected = c == config;
                                }
                              });
                            },
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _isConnected || _selectedConfig == null
                        ? null
                        : _connect,
                    child: const Text('Подключить'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isConnected ? _disconnect : null,
                    child: const Text('Отключить'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _selectedConfig == null ? null : _pingSelected,
              icon: const Icon(Icons.speed),
              label: const Text('Ping'),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 100,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    _logs.isEmpty ? 'Логи...' : _logs,
                    style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
