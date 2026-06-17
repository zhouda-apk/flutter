import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../config/llm_backend_settings.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isClearing = false;

  Future<void> _clearTemporaryImages() async {
    if (_isClearing) return;
    setState(() => _isClearing = true);

    var deletedFiles = 0;
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final targets = <Directory>[];

      await for (final entity in appDir.list(recursive: true)) {
        if (entity is Directory && p.basename(entity.path) == 'preprocessed') {
          targets.add(entity);
        }
      }

      for (final directory in targets) {
        if (!await directory.exists()) continue;
        await for (final entity in directory.list(recursive: true)) {
          if (entity is File) deletedFiles++;
        }
        await directory.delete(recursive: true);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已清除 $deletedFiles 個暫存圖片檔')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('清除暫存失敗：$e')),
      );
    } finally {
      if (mounted) setState(() => _isClearing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('設定'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          const _SettingsSection(
            title: 'OCR',
            children: [
              _SettingsTile(
                icon: Icons.translate_outlined,
                title: '辨識語言',
                subtitle: '繁體中文優先，失敗時自動降級為通用模型',
                trailing: Text('自動'),
              ),
              _SettingsTile(
                icon: Icons.tune_outlined,
                title: '圖片前處理',
                subtitle: '自動文件模式：亮度、對比、灰階與銳化',
                trailing: Text('自動'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SettingsSection(
            title: '資料',
            children: [
              _SettingsTile(
                icon: Icons.cleaning_services_outlined,
                title: '清除前處理暫存圖片',
                subtitle: '只清除 OCR 前處理輸出的暫存圖，不刪除已儲存筆記',
                trailing: _isClearing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : TextButton(
                        onPressed: _clearTemporaryImages,
                        child: const Text('清除'),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const _SettingsSection(
            title: '開發',
            children: [
              _SettingsTile(
                icon: Icons.link_outlined,
                title: '目前後端 URL',
                subtitle: LlmBackendSettings.backendBaseUrl,
              ),
              _SettingsTile(
                icon: Icons.timer_outlined,
                title: '請求逾時',
                subtitle: '${LlmBackendSettings.timeoutSeconds} 秒',
              ),
              _SettingsTile(
                icon: Icons.science_outlined,
                title: 'Mock Mode',
                subtitle: LlmBackendSettings.mockMode ? '開啟' : '關閉',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppColors.primary, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 10),
            DefaultTextStyle(
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600,
              ),
              child: trailing!,
            ),
          ],
        ],
      ),
    );
  }
}
