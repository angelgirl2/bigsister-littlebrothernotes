import 'package:flutter/material.dart';

import '../cloud/cloud_service.dart';
import '../models/app_models.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

class _LoginRoleHint extends StatelessWidget {
  const _LoginRoleHint();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      color: Colors.white.withValues(alpha: .04),
      border: Border.all(color: Colors.white.withValues(alpha: .07)),
    ),
    child: const Row(
      children: [
        Icon(Icons.lock_person_rounded, color: Colors.white70),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'ورود خودکار است: رمز آبجی بزرگ یا رمز داداش کوچیکه مشخص می‌کند چه کسی وارد شده است.',
            style: TextStyle(color: Colors.white70, height: 1.5),
          ),
        ),
      ],
    ),
  );
}

class CloudSharedLoginScreen extends StatefulWidget {
  const CloudSharedLoginScreen({
    super.key,
    required this.storage,
    required this.theme,
  });

  final StorageService storage;
  final AppThemeChoice theme;

  @override
  State<CloudSharedLoginScreen> createState() => _CloudSharedLoginScreenState();
}

class _CloudSharedLoginScreenState extends State<CloudSharedLoginScreen> {
  final CloudService cloud = CloudService.instance;
  final password = TextEditingController();
  bool busy = false;
  String? status;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    password.dispose();
    super.dispose();
  }

  String _errorText(Object error) {
    final raw = error.toString();

    if (raw.contains('invalid_login')) {
      return 'رمز ورود اشتباه است.';
    }

    if (raw.contains('duplicate_passwords')) {
      return 'دو رمز نباید یکسان باشند.';
    }

    if (raw.contains('server_not_ready') ||
        raw.contains('database_not_ready') ||
        raw.contains('database_unavailable') ||
        raw.contains('login_failed')) {
      return 'سرور دفتر مشترک آماده نیست؛ وضعیت Railway و PostgreSQL را بررسی کن.';
    }

    if (raw.contains('DioException') ||
        raw.contains('SocketException') ||
        raw.contains('connection refused') ||
        raw.contains('failed host lookup')) {
      return 'ارتباط با سرور برقرار نشد؛ اینترنت و Railway را بررسی کن.';
    }

    if (raw.contains('server_credentials_missing')) {
      return 'حساب‌های دفتر روی سرور تنظیم نشده‌اند.';
    }

    return 'خطای ورود رخ داد. دوباره تلاش کن.';
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
      // ورود به دفتر مشترک
      await cloud.login(password: password.text.trim());

      if (mounted) {
        setState(() {
          status = 'ورود موفق بود؛ در حال آماده‌سازی دفتر... ❤️';
        });
      }

      // اگر همگام‌سازی مشکل داشت، نباید ورود را خراب کند
      try {
        await cloud.pullAndApply(widget.storage);
        await cloud.syncNow(widget.storage);
      } catch (syncError) {
        debugPrint('SYNC ERROR: $syncError');
      }

      if (mounted) {
        setState(() {
          status = 'اتصال مشترک فعال شد ❤️🫂';
        });
      }
    } catch (e) {
      debugPrint('LOGIN ERROR: $e');

      if (mounted) {
        setState(() {
          status = _errorText(e);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
        });
      }
    }
  }

  Future<void> disconnect() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('قطع ارتباط'),
        content: const Text(
          'ارتباط این دستگاه با دفتر دو نفره قطع شود؟ اطلاعات محلی حذف نمی‌شود.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('لغو'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('قطع ارتباط'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await cloud.disconnect();
    if (mounted)
      setState(() => status = 'ارتباط قطع شد. اطلاعات محلی باقی ماند.');
  }

  @override
  Widget build(BuildContext context) {
    final c = colorsFor(widget.theme);
    return Scaffold(
      backgroundColor: AppPalette.page,
      appBar: AppBar(
        title: const Text('دفتر مشترک آبجی بزرگ و داداش کوچیکه'),
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
                const Text(
                  'آبجی بزرگ ↔ داداش کوچیکه',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                const Text(
                  'یادداشت‌ها، چت و نامه‌ها بین آبجی بزرگ و داداش کوچیکه مستقیم روی هر دو گوشی دیده می‌شوند. هیچ کد جفت‌سازی یا آدرس جداگانه‌ای لازم نیست.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white60, height: 1.6),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const SizedBox(height: 14),
          const _LoginRoleHint(),
          const SizedBox(height: 16),
          if (cloud.configured) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: c.primary.withValues(alpha: .08),
                border: Border.all(color: c.primary.withValues(alpha: .16)),
              ),
              child: Row(
                children: [
                  Icon(Icons.verified_user_rounded, color: c.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'وارد شده‌ای: ${cloud.myDisplayName} ❤️\nرمز روی این دستگاه ذخیره شده و تا وقتی «قطع ارتباط» را نزنی دوباره درخواست نمی‌شود.',
                      style: const TextStyle(height: 1.55, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            TextField(
              controller: password,
              obscureText: true,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(
                labelText: 'رمز شخص خودت',
                hintText: 'رمز آبجی بزرگ یا داداش کوچیکه را وارد کن',
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
              'رمز فقط یک‌بار روی این دستگاه وارد می‌شود. تا وقتی قطع ارتباط نکنی، ورود دوباره لازم نیست.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: .58),
                height: 1.55,
              ),
            ),
          ],
          if (cloud.configured) ...[
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: busy ? null : disconnect,
              icon: const Icon(Icons.link_off_rounded),
              label: const Text('قطع ارتباط این دستگاه'),
            ),
            const SizedBox(height: 8),
            Text(
              cloud.online
                  ? '● اتصال زنده برقرار است'
                  : '● اتصال ذخیره شده است؛ هنوز آنلاین نیست',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: cloud.online ? c.primary : Colors.white54,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (busy) ...[
            const SizedBox(height: 18),
            const Center(child: CircularProgressIndicator()),
          ],
          if (status != null) ...[
            const SizedBox(height: 18),
            Text(
              status!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, height: 1.5),
            ),
          ],
        ],
      ),
    );
  }
}
