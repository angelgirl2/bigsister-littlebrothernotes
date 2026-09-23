import 'package:flutter/material.dart';

import '../cloud/cloud_service.dart';
import '../models/app_models.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

class CloudSharedLoginScreen extends StatefulWidget {
  const CloudSharedLoginScreen({super.key, required this.storage, required this.theme});

  final StorageService storage;
  final AppThemeChoice theme;

  @override
  State<CloudSharedLoginScreen> createState() => _CloudSharedLoginScreenState();
}

class _CloudSharedLoginScreenState extends State<CloudSharedLoginScreen> {
  final CloudService cloud = CloudService.instance;
  late final TextEditingController server;
  final password = TextEditingController();
  String role = 'me';
  bool busy = false;
  String? status;

  @override
  void initState() {
    super.initState();
    server = TextEditingController(
      text: cloud.baseUrl?.isNotEmpty == true
          ? cloud.baseUrl!
          : const String.fromEnvironment('BIG_SISTER_API_URL', defaultValue: ''),
    );
    if (cloud.role != null) role = cloud.role!;
  }

  @override
  void dispose() {
    server.dispose();
    password.dispose();
    super.dispose();
  }

  String _errorText(Object error) {
    final raw = error.toString();
    if (raw.contains('invalid_login')) return 'رمز ورود اشتباه است.';
    if (raw.contains('server_credentials_missing')) return 'حساب‌های دفتر روی سرور تنظیم نشده‌اند.';
    return 'اتصال به Railway برقرار نشد. آدرس سرویس و اینترنت را بررسی کن.';
  }

  Future<bool> _prepareServer() async {
    if (server.text.trim().isEmpty) {
      setState(() => status = 'آدرس Railway را وارد کن.');
      return false;
    }
    await cloud.setServerUrl(server.text.trim());
    return true;
  }

  Future<void> login() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (password.text.trim().length < 4) {
      setState(() => status = 'رمز ورود را وارد کن.');
      return;
    }
    setState(() {
      busy = true;
      status = null;
    });
    try {
      if (!await _prepareServer()) return;
      await cloud.login(role: role, password: password.text.trim());
      await cloud.pullAndApply(widget.storage);
      await cloud.syncNow(widget.storage);
      if (mounted) setState(() => status = 'اتصال مشترک فعال شد ❤️🫂');
    } catch (e) {
      if (mounted) setState(() => status = _errorText(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> disconnect() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('قطع ارتباط'),
        content: const Text('ارتباط این دستگاه با دفتر دو نفره قطع شود؟ اطلاعات محلی حذف نمی‌شود.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('لغو')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('قطع ارتباط')),
        ],
      ),
    );
    if (ok != true) return;
    await cloud.disconnect();
    if (mounted) setState(() => status = 'ارتباط قطع شد. اطلاعات محلی باقی ماند.');
  }

  @override
  Widget build(BuildContext context) {
    final c = colorsFor(widget.theme);
    return Scaffold(
      backgroundColor: AppPalette.page,
      appBar: AppBar(
        title: const Text('دفتر مشترک من و آبجی'),
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              color: const Color(0xFF090F19),
              border: Border.all(color: c.primary.withValues(alpha: .12)),
            ),
            child: Column(
              children: [
                Icon(Icons.people_alt_rounded, color: c.primary, size: 54),
                const SizedBox(height: 12),
                const Text('من ↔ آبجی', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                const Text(
                  'هر چیزی که تو یا آبجی بنویسید، عکس بگذارید، صدا بفرستید یا در چت ارسال کنید، خودکار روی هر دو گوشی دیده می‌شود.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white60, height: 1.6),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: server,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'آدرس Railway',
              hintText: 'https://YOUR-APP.up.railway.app',
              prefixIcon: Icon(Icons.dns_rounded),
            ),
          ),
          const SizedBox(height: 14),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'me', label: Text('من'), icon: Icon(Icons.person_rounded)),
              ButtonSegment(value: 'sister', label: Text('آبجی'), icon: Icon(Icons.favorite_rounded)),
            ],
            selected: {role},
            onSelectionChanged: (s) => setState(() => role = s.first),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: password,
            obscureText: true,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(
              labelText: 'رمز ورود',
              hintText: 'رمزی که در Railway برای این شخص تنظیم شده',
              prefixIcon: Icon(Icons.password_rounded),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: busy ? null : login,
            icon: const Icon(Icons.login_rounded),
            label: const Text('ورود و اتصال خودکار'),
          ),
          const SizedBox(height: 10),
          Text(
            'این ورود فقط یک‌بار لازم است. بعد از آن برنامه هنگام اجرا خودش دفتر مشترک را همگام می‌کند و دیگر هیچ کد جفت‌سازی نیاز نیست.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: .58), height: 1.55),
          ),
          if (cloud.configured) ...[
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: busy ? null : disconnect,
              icon: const Icon(Icons.link_off_rounded),
              label: const Text('قطع ارتباط این دستگاه'),
            ),
            const SizedBox(height: 8),
            Text(
              cloud.online ? '● اتصال زنده برقرار است' : '● اتصال ذخیره شده است؛ هنوز آنلاین نیست',
              textAlign: TextAlign.center,
              style: TextStyle(color: cloud.online ? c.primary : Colors.white54, fontWeight: FontWeight.w700),
            ),
          ],
          if (busy) ...[
            const SizedBox(height: 18),
            const Center(child: CircularProgressIndicator()),
          ],
          if (status != null) ...[
            const SizedBox(height: 18),
            Text(status!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, height: 1.5)),
          ],
        ],
      ),
    );
  }
}
