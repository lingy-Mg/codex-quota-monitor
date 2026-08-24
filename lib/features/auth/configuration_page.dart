import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/monitor_controller.dart';
import '../../app/theme.dart';
import '../../services/local_auth_file_service.dart';

class ConfigurationPage extends ConsumerStatefulWidget {
  const ConfigurationPage({super.key});
  @override
  ConsumerState<ConfigurationPage> createState() => _ConfigurationPageState();
}

class _ConfigurationPageState extends ConsumerState<ConfigurationPage> {
  final _text = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (LocalAuthFileService.supportsAutomaticDiscovery) {
      _detectWindowsAuthFile();
    }
  }

  Future<void> _detectWindowsAuthFile() async {
    setState(() => _busy = true);
    try {
      final authJson = await const LocalAuthFileService().readWindowsAuthJson();
      if (authJson != null && authJson.trim().isNotEmpty) {
        await _submit(authJson);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = '无法自动读取本机 auth.json，请手动导入。');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit(String text) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(dashboardProvider.notifier).importCredentials(text);
    } on FormatException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = '无法读取凭据，请确认 auth.json 格式。');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pick() async {
    final f = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    final bytes = f?.files.single.bytes;
    if (bytes != null) await _submit(String.fromCharCodes(bytes));
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: LayoutBuilder(
      builder: (context, viewport) => SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: viewport.maxHeight - 40),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Container(
                padding: const EdgeInsets.all(36),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.monitor_heart_outlined,
                      size: 52,
                      color: AppColors.cyan,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '尚未配置 Codex',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Windows 会自动识别本机 Codex CLI 的 auth.json；也可手动导入。凭据仅保存在系统安全存储中。',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.muted),
                    ),
                    const SizedBox(height: 26),
                    FilledButton.icon(
                      onPressed: _busy ? null : _pick,
                      icon: const Icon(Icons.file_open_outlined),
                      label: Text(_busy ? '正在识别本机 auth.json…' : '导入 auth.json'),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      '或粘贴 auth.json 内容',
                      style: TextStyle(color: AppColors.muted),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _text,
                      maxLines: 6,
                      autocorrect: false,
                      enableSuggestions: false,
                      // auth.json is formatted JSON, so users must be able to paste
                      // multiple lines. Flutter only supports obscuring single-line
                      // fields; credentials are persisted securely after submission.
                      obscureText: false,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: '{ "tokens": { ... } }',
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _busy || _text.text.trim().isEmpty
                          ? null
                          : () => _submit(_text.text),
                      child: Text(_busy ? '正在验证…' : '保存并开始监控'),
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: AppColors.error),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
