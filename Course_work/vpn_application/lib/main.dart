import 'package:flutter/material.dart';
import 'package:v2ray_box/v2ray_box.dart';

import 'subscription_service.dart';

late final V2rayBox v2ray;

const defaultSubscriptionUrl = 'https://sub.kami-sleep.de/fpQU3dw3R4o1wnxj';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  v2ray = V2rayBox();
  await v2ray.initialize(notificationStopButtonText: 'Отключить');
  await v2ray.setCoreEngine('xray');
  await v2ray.setServiceMode(VpnMode.vpn);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6C5CE7)),
        useMaterial3: true,
      ),
      home: const VpnPage(),
    );
  }
}

class VpnPage extends StatefulWidget {
  const VpnPage({super.key});

  @override
  State<VpnPage> createState() => _VpnPageState();
}

class _VpnPageState extends State<VpnPage> {
  final _subUrlController = TextEditingController(text: defaultSubscriptionUrl);

  VpnStatus _status = VpnStatus.stopped;
  String _logs = '';
  bool _loadingSub = false;
  String? _error;

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

  @override
  void dispose() {
    _subUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadSubscription() async {
    setState(() {
      _loadingSub = true;
      _error = null;
    });

    try {
      final links = await SubscriptionService.fetchConfigLinks(
        _subUrlController.text.trim(),
      );
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
        _configs = configs;
        _selectedConfig = configs.first;
        for (final c in _configs) {
          c.isSelected = c == _selectedConfig;
        }
      });
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

  bool get _isConnected =>
      _status == VpnStatus.started || _status == VpnStatus.starting;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('VPN'),
        actions: [
          IconButton(
            onPressed: _loadingSub ? null : _loadSubscription,
            icon: const Icon(Icons.refresh),
            tooltip: 'Обновить подписку',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _subUrlController,
              decoration: const InputDecoration(
                labelText: 'Subscription URL',
                border: OutlineInputBorder(),
                hintText: 'https://... или sub://...',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _loadingSub ? null : _loadSubscription,
              icon: _loadingSub
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_download),
              label: Text(_loadingSub ? 'Загрузка...' : 'Загрузить подписку'),
            ),
            const SizedBox(height: 12),
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
                      child: Text(
                        _loadingSub
                            ? 'Загрузка конфигов...'
                            : 'Нет конфигов. Нажмите «Загрузить подписку».',
                      ),
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
