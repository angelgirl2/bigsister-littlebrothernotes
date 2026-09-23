import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:local_auth/local_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:record/record.dart';
import 'package:share_plus/share_plus.dart';

import 'models/app_models.dart';
import 'cloud/cloud_service.dart';
import 'screens/chat_screen.dart';
import 'screens/cloud_login_screen.dart';
import 'screens/splash_screen.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';
import 'theme/app_theme.dart';
import 'widgets/animated_background.dart';

const quotes = <String>[
  'تو از چیزی که فکر می‌کنی قوی‌تری؛ فقط گاهی یادت می‌رود.',
  'هر روز لازم نیست عالی باشی؛ فقط یک قدم جلوتر برو.',
  'آرام‌آرام هم می‌شود به رویاهای بزرگ رسید.',
  'تو شایسته‌ی آرامش، احترام و تمام خوبی‌های دنیایی.',
  'هیچ شب سختی برای همیشه نمی‌ماند؛ صبح بالاخره می‌رسد.',
  'به خودت همان مهربانی را بده که به عزیزانت می‌دهی.',
  'اشتباه کردن بخشی از مسیر است، نه پایان مسیر.',
  'تو برای درخشیدن ساخته شده‌ای، حتی در روزهای ابری.',
  'گاهی استراحت کردن هم یک شکل از پیشرفت است.',
  'یک روز معمولی هم می‌تواند شروع یک اتفاق فوق‌العاده باشد.',
  'به قلبت اعتماد کن؛ تو خیلی بیشتر از چیزی که فکر می‌کنی می‌دانی.',
  'هیچ‌کس شبیه تو نیست؛ همین تو را خاص می‌کند.',
  'قدرت تو همیشه در بی‌نقص بودن نیست؛ در دوباره بلند شدن است.',
  'امروز لازم نیست همه‌چیز را حل کنی؛ فقط امروز را زندگی کن.',
  'تو دلیل‌های زیادی برای افتخار کردن به خودت داری.',
  'دلتنگی هم می‌تواند شکل دیگری از عشق باشد.',
  'وقتی دنیا شلوغ می‌شود، به صدای آرام قلبت گوش بده.',
  'تو لایق روزهایی هستی که لبخند زدن در آن‌ها سخت نباشد.',
  'هیچ قدم کوچکی بی‌ارزش نیست؛ مسیر با همین قدم‌ها ساخته می‌شود.',
  'برای آینده‌ات امیدوار بمان؛ هنوز فصل‌های زیبایی باقی مانده‌اند.',
];

const letterTemplates = <String, String>{
  'وقتی خسته‌ای':
      'خواهر بزرگم، اگر امروز خسته‌ای، لازم نیست همه‌چیز را همین امروز حل کنی. یک نفس عمیق بکش، کمی استراحت کن و یادت باشد من به بودنت افتخار می‌کنم. ❤️',
  'برای یک روز سخت':
      'می‌دانم امروز ساده نیست. اما تو بارها از روزهای سخت عبور کرده‌ای. این یکی هم می‌گذرد. من کنارت هستم، حتی اگر فقط در یک جمله یا یک آغوش از دور باشد. 🫂',
  'برای موفقیت':
      'دیدن موفقیتت خوشحالم می‌کند. هر قدم کوچک تو ارزش جشن گرفتن دارد. ادامه بده؛ آینده برای آدم‌های شجاعی مثل تو جا دارد. ✨',
  'شب آرام':
      'امشب همه نگرانی‌ها را برای چند ساعت زمین بگذار. فردا فرصت تازه‌ای است. بخواب، نفس بکش و بدان که برای من همیشه باارزشی. 🌙',
  'بی‌دلیل دوستت دارم':
      'این نامه دلیل خاصی ندارد؛ فقط خواستم بدانی داشتن خواهری مثل تو یکی از چیزهایی است که برایش شکرگزارم. همین. ❤️🫂',
  'بهت افتخار می‌کنم':
      'شاید همیشه به زبان نیاورم، اما واقعاً به مسیرت، تلاش‌هایت و آدمی که هستی افتخار می‌کنم. 🌷',
  'صبح تازه':
      'صبح بخیر خواهر بزرگم. امروز را با این فکر شروع کن که هنوز کلی اتفاق خوب می‌تواند سر راهت قرار بگیرد. ☀️',
  'وقتی ناامیدی':
      'اگر امروز امیدت کم شده، اشکالی ندارد. فعلاً فقط یک قدم کوچک بردار. لازم نیست تمام مسیر را همین حالا ببینی. 💙',
  'وقتی به خودت شک داری':
      'به خودت شک نکن. تو قبلاً از چیزهایی عبور کرده‌ای که روزی فکر می‌کردی نمی‌توانی. این بار هم می‌توانی. ✨',
  'برای لبخندت':
      'فقط آمده‌ام یادآوری کنم که لبخندت یکی از دوست‌داشتنی‌ترین چیزهای دنیاست. پس امروز یک دلیل کوچک برای لبخند پیدا کن. 😊',
  'آغوش از دور':
      'اگر الان کنارم بودی، قبل از هر حرفی بغلت می‌کردم. تا آن زمان این چند کلمه را به جای آن آغوش نگه دار. 🫂❤️',
  'برای رویاهایت':
      'رویاهایت را کوچک نکن تا با ترس‌هایت هماهنگ شوند. بزرگ فکر کن؛ تو شایسته‌ی اتفاق‌های بزرگ هستی. 🌌',
  'وقتی اشتباه کردی':
      'یک اشتباه، تعریف تو نیست. از آن یاد بگیر، خودت را ببخش و دوباره ادامه بده. آدم‌های قوی هم اشتباه می‌کنند. 🌱',
  'برای یک شب بارانی':
      'اگر امروز شلوغ و سنگین بود، بگذار شب آرامت کند. فردا دوباره می‌توانی شروع کنی؛ امشب فقط نفس بکش. 🌧️',
  'تشکر ساده':
      'ممنون که خواهری هستی که بودنش خودش یک حس خوب است. شاید ساده به نظر برسد، اما برای من خیلی ارزشمند است. ❤️',
  'برای روزهای بزرگ':
      'روزی که به چیزهایی که آرزویشان را داری رسیدی، یادت باشد یک روز از همین‌جا و با همین قدم‌های کوچک شروع کرده بودی. ⭐',
  'تو کافی هستی':
      'لازم نیست برای ارزشمند بودن، همیشه قوی و بی‌نقص باشی. همین که خودت هستی، کافی است. 🤍',
  'وقتی نیاز به استراحت داری':
      'استراحت کردن عقب افتادن نیست. گاهی بهترین کاری که می‌توانی برای آینده‌ات بکنی، همین است که امروز کمی آرام‌تر باشی. 🌙',
  'یک یادآوری کوچک':
      'آب بخور، نفس عمیق بکش، شانه‌هایت را رها کن و یادت باشد کسی هست که از ته قلبش دوستت دارد. ❤️',
  'نامه‌ی بی‌مناسبت':
      'هیچ مناسبت خاصی نیست. فقط خواستم یک لحظه از روزت را با یک جمله روشن کنم: خیلی دوستت دارم خواهر بزرگم. 🫂',
  'وقتی می‌ترسی':
      'ترس به معنی ناتوانی نیست؛ فقط یعنی این اتفاق برایت مهم است. قدم کوچکت را بردار و باقی مسیر خودش روشن‌تر می‌شود. 🌱',
  'وقتی دلت گرفته':
      'لازم نیست برای غمت توضیحی داشته باشی. اجازه بده احساسش کنی، بعد کم‌کم سبک‌تر شو. من همیشه از خوشحالی تو خوشحال می‌شوم. 💙',
  'وقتی دلتنگی':
      'دلتنگی نشانه‌ی این است که چیزی برایت مهم بوده. بگذار این دلتنگی تبدیل به یک خاطره‌ی گرم شود. 🫂',
  'برای تولد':
      'تولدت فقط یک تاریخ نیست؛ یادآوری روزی است که دنیا یک انسان دوست‌داشتنی‌تر به خودش دید. تولدت مبارک خواهر بزرگم. 🎂❤️',
  'برای فردا':
      'هر روز لازم نیست جواب همه‌چیز را بداند. کافی است اجازه بده فردا خودش یک بخش از جواب را برایت بیاورد. 🌅',
  'شب قبل از یک اتفاق مهم':
      'فردا هرچه شد، ارزش تو را تعیین نمی‌کند. فقط برو و تمام تلاشت را بکن؛ همین کافی است. 🍀',
  'برای روزهای شلوغ':
      'وسط تمام کارهای امروز، حداقل پنج دقیقه فقط برای خودت نگه دار. تو هم جزو کارهای مهم این فهرستی. 💗',
  'برای یک آغوش':
      'این نامه را مثل یک آغوش کوچک ذخیره کن؛ هر وقت خواستی بازش کن. 🫂',
  'برای روزی که برق می‌زنی':
      'همیشه همین‌طور بدرخش؛ نه برای تأیید دیگران، برای اینکه خودت را دوست داری. ✨',
  'من اینجام':
      'هرقدر دنیا تغییر کند، یک جمله ثابت می‌ماند: من اینجام، خواهر بزرگم. ❤️',
  'بدون دلیل':
      'نه مناسبت دارد، نه دلیل. فقط چون تویی. همین برای نوشتن این نامه کافی است. 🌷',
};

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = await StorageService.create();
  await storage.purgeOldTrash();
  await NotificationService.instance.initialize();
  await CloudService.instance.init();
  await initializeDateFormatting('fa');
  runApp(BigSisterApp(storage: storage));
}

class BigSisterApp extends StatefulWidget {
  const BigSisterApp({super.key, required this.storage});
  final StorageService storage;
  @override
  State<BigSisterApp> createState() => _BigSisterAppState();
}

class _BigSisterAppState extends State<BigSisterApp> {
  late AppThemeChoice theme = widget.storage.loadTheme();
  bool ready = false;
  @override
  Widget build(BuildContext context) {
    final c = colorsFor(theme);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Big Sister Notes',
      theme: buildDarkTheme(theme),
      // بعضی Routeها/ویجت‌های Material در صورت نداشتن رنگ سطح،
      // رنگ خاکستری پیش‌فرض سیستم را تا قبل از paint شدن محتوا نشان می‌دهند.
      // این لایه باعث می‌شود کل viewport همیشه پس‌زمینه‌ی خود برنامه را داشته باشد.
      builder: (context, child) => ColoredBox(
        color: AppPalette.page,
        child: child ?? const SizedBox.expand(),
      ),
      home: !ready
          ? SplashScreen(
              primary: c.primary,
              onDone: () => setState(() => ready = true),
            )
          : MainShell(
              storage: widget.storage,
              theme: theme,
              onThemeChanged: (v) async {
                await widget.storage.saveTheme(v);
                setState(() => theme = v);
              },
            ),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    required this.storage,
    required this.theme,
    required this.onThemeChanged,
  });
  final StorageService storage;
  final AppThemeChoice theme;
  final ValueChanged<AppThemeChoice> onThemeChanged;
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late List<NoteItem> notes;
  late List<NoteItem> trash;
  int tab = 0;
  late int quoteIndex;
  bool locked = false;
  StreamSubscription<void>? _cloudSubscription;
  StreamSubscription<bool>? _cloudConnectionSubscription;

  @override
  void initState() {
    super.initState();
    notes = widget.storage.activeNotes();
    trash = widget.storage.trashNotes();
    locked = widget.storage.loadPin() != null || widget.storage.loadBiometric();
    quoteIndex = 0;
    quoteIndex = widget.storage.dailyQuoteIndex(quotes.length);
    widget.storage.setCloudChangedCallback(() => CloudService.instance.syncNow(widget.storage));
    _cloudSubscription = CloudService.instance.contentChanges.listen((_) async {
      await _applyRemoteCloud();
    });
    _cloudConnectionSubscription = CloudService.instance.connectionChanges.listen((online) {
      if (online) {
        unawaited(_startupCloudSync());
      }
      if (mounted) setState(() {});
    });
    if (CloudService.instance.configured) {
      Future.microtask(_startupCloudSync);
    }
  }

  Future<void> _startupCloudSync() async {
    await CloudService.instance.pullAndApply(widget.storage);
    await CloudService.instance.syncNow(widget.storage);
    if (mounted) refresh();
  }

  Future<void> _applyRemoteCloud() async {
    if (!CloudService.instance.configured) return;
    await CloudService.instance.pullAndApply(widget.storage);
    for (final n in widget.storage.activeNotes()) {
      if (n.reminderAt != null && n.reminderAt!.isAfter(DateTime.now())) {
        await NotificationService.instance.scheduleNoteReminder(noteId: n.id, title: n.title, when: n.reminderAt!);
      } else {
        await NotificationService.instance.cancelNoteReminder(n.id);
      }
    }
    if (mounted) refresh();
  }

  @override
  void dispose() {
    _cloudSubscription?.cancel();
    _cloudConnectionSubscription?.cancel();
    widget.storage.setCloudChangedCallback(null);
    super.dispose();
  }

  void refresh() => setState(() {
    notes = widget.storage.activeNotes();
    trash = widget.storage.trashNotes();
  });
  Future<void> persist() async {
    await widget.storage.saveNotes([...notes, ...trash]);
    refresh();
  }

  Future<void> openEditor({NoteItem? initial, NoteKind? kind}) async {
    final result = await Navigator.of(context).push<NoteItem>(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (_, animation, __) => FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          ),
          child: NoteEditorScreen(
            storage: widget.storage,
            theme: widget.theme,
            initial: initial,
            initialKind: kind,
            onDelete: initial == null ? null : () => moveToTrash(initial),
          ),
        ),
      ),
    );
    if (result == null) return;
    await _saveNote(result);
  }

  Future<void> _saveNote(NoteItem note) async {
    note.updatedAt = DateTime.now();
    await widget.storage.upsert(note);
    if (note.reminderAt != null) {
      await NotificationService.instance.scheduleNoteReminder(
        noteId: note.id,
        title: note.title,
        when: note.reminderAt!,
      );
    } else {
      await NotificationService.instance.cancelNoteReminder(note.id);
    }
    refresh();
  }

  Future<void> moveToTrash(NoteItem note) async {
    await widget.storage.moveToTrash(note.id);
    await NotificationService.instance.cancelNoteReminder(note.id);
    refresh();
  }

  Future<void> newQuick(String label, NoteKind kind) => openEditor(kind: kind);

  @override
  Widget build(BuildContext context) {
    if (locked)
      return LockScreen(
        storage: widget.storage,
        onUnlock: () => setState(() => locked = false),
      );
    final c = colorsFor(widget.theme);
    final pages = [
      HomeTab(
        notes: notes,
        theme: widget.theme,
        quoteIndex: quoteIndex,
        onNew: () => openEditor(),
        onNavigate: (i) => setState(() => tab = i),
        onOpenNote: (n) => openEditor(initial: n),
      ),
      NotesTab(
        notes: notes,
        theme: widget.theme,
        onOpen: (n) => openEditor(initial: n),
        onDelete: moveToTrash,
        onRefresh: (_) => refresh(),
      ),
      ChatScreen(theme: widget.theme),
      MemoriesTab(
        notes: notes,
        theme: widget.theme,
        onOpen: (n) => openEditor(initial: n),
        onDelete: moveToTrash,
        onRefresh: (_) => refresh(),
      ),
      LettersTab(
        theme: widget.theme,
        onUse: (title, text) async {
          final now = DateTime.now();
          await _saveNote(
            NoteItem(
              id: now.microsecondsSinceEpoch.toString(),
              title: title,
              body: text,
              createdAt: now,
              updatedAt: now,
              kind: NoteKind.letter,
              folder: NoteFolder.letters,
            ),
          );
          setState(() => tab = 1);
        },
      ),
      SettingsTab(
        storage: widget.storage,
        theme: widget.theme,
        cloud: CloudService.instance,
        trash: trash,
        onTheme: widget.onThemeChanged,
        onRefresh: refresh,
        onLockChange: () => setState(
          () => locked =
              widget.storage.loadPin() != null ||
              widget.storage.loadBiometric(),
        ),
      ),
    ];
    return Scaffold(
      extendBody: true,
      backgroundColor: AppPalette.page,
      body: ColoredBox(
        color: AppPalette.page,
        child: AnimatedBackground(
          primary: c.primary,
          secondary: c.secondary,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, a) => FadeTransition(
              opacity: CurvedAnimation(parent: a, curve: Curves.easeOutCubic),
              child: child,
            ),
            child: KeyedSubtree(key: ValueKey(tab), child: pages[tab]),
          ),
        ),
      ),
      floatingActionButton: tab <= 1
          ? _AnimatedFab(color: c.primary, onTap: () => openEditor())
          : null,
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFF080D16),
              borderRadius: BorderRadius.circular(38),
              border: Border.all(color: Colors.white.withValues(alpha: .06)),
              boxShadow: [
                BoxShadow(
                  color: c.glow.withValues(alpha: .08),
                  blurRadius: 28,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(38),
              child: NavigationBar(
                backgroundColor: Colors.transparent,
                height: 74,
                selectedIndex: tab,
                onDestinationSelected: (i) => setState(() => tab = i),
                destinations: [
                  NavigationDestination(
                    icon: Icon(Icons.home_outlined, color: Colors.white70),
                    selectedIcon: Icon(Icons.home_rounded, color: c.primary),
                    label: 'خانه',
                  ),
                  NavigationDestination(
                    icon: Icon(
                      Icons.sticky_note_2_outlined,
                      color: Colors.white70,
                    ),
                    selectedIcon: Icon(
                      Icons.sticky_note_2_rounded,
                      color: c.primary,
                    ),
                    label: 'یادداشت‌ها',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.forum_outlined, color: Colors.white70),
                    selectedIcon: Icon(Icons.forum_rounded, color: c.primary),
                    label: 'چت',
                  ),
                  NavigationDestination(
                    icon: Icon(
                      Icons.photo_library_outlined,
                      color: Colors.white70,
                    ),
                    selectedIcon: Icon(
                      Icons.photo_library_rounded,
                      color: c.primary,
                    ),
                    label: 'خاطره‌ها',
                  ),
                  NavigationDestination(
                    icon: Icon(
                      Icons.mail_outline_rounded,
                      color: Colors.white70,
                    ),
                    selectedIcon: Icon(Icons.mail_rounded, color: c.primary),
                    label: 'نامه‌ها',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.settings_outlined, color: Colors.white70),
                    selectedIcon: Icon(
                      Icons.settings_rounded,
                      color: c.primary,
                    ),
                    label: 'تنظیمات',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedFab extends StatelessWidget {
  const _AnimatedFab({required this.color, required this.onTap});
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => FloatingActionButton.extended(
    elevation: 6,
    backgroundColor: color,
    foregroundColor: Colors.black,
    onPressed: onTap,
    icon: const Icon(Icons.add_rounded, size: 28),
    label: const Text(
      'یادداشت جدید',
      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
    ),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
  );
}

class _Reveal extends StatelessWidget {
  const _Reveal({required this.child, this.delay = Duration.zero})
    : offset = const Offset(0, .08);
  final Widget child;
  final Duration delay;
  final Offset offset;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    duration: Duration(milliseconds: 520 + delay.inMilliseconds),
    curve: Curves.easeOutCubic,
    tween: Tween(begin: 0, end: 1),
    builder: (_, v, __) => Opacity(
      opacity: v,
      child: FractionalTranslation(
        translation: Offset(offset.dx * (1 - v), offset.dy * (1 - v)),
        child: child,
      ),
    ),
  );
}

class _BreathingLogo extends StatefulWidget {
  const _BreathingLogo({required this.color});
  final Color color;

  @override
  State<_BreathingLogo> createState() => _BreathingLogoState();
}

class _BreathingLogoState extends State<_BreathingLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat(reverse: true);

  late final Animation<double> _scale = Tween<double>(
    begin: .96,
    end: 1.04,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  late final Animation<double> _glow = Tween<double>(
    begin: .12,
    end: .30,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scale.value,
          child: Container(
            width: 66,
            height: 66,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.color.withValues(alpha: .08),
              border: Border.all(color: widget.color.withValues(alpha: .18)),
              boxShadow: [
                BoxShadow(
                  color: widget.color.withValues(alpha: _glow.value),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/logo.png',
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
                errorBuilder: (context, error, stackTrace) =>
                    Icon(Icons.favorite_rounded, color: widget.color, size: 32),
              ),
            ),
          ),
        );
      },
    );
  }
}

class HomeTab extends StatelessWidget {
  const HomeTab({
    super.key,
    required this.notes,
    required this.theme,
    required this.quoteIndex,
    required this.onNew,
    required this.onNavigate,
    required this.onOpenNote,
  });
  final List<NoteItem> notes;
  final AppThemeChoice theme;
  final int quoteIndex;
  final VoidCallback onNew;
  final ValueChanged<int> onNavigate;
  final ValueChanged<NoteItem> onOpenNote;

  String greeting() {
    final h = DateTime.now().hour;
    if (h < 11) return 'صبح بخیر آبجی بزرگم';
    if (h < 15) return 'ظهر بخیر خواهر بزرگم';
    if (h < 19) return 'عصر بخیر آبجی';
    return 'شب بخیر خواهرم';
  }

  String _messageForHour() {
    final h = DateTime.now().hour;
    if (h < 11)
      return 'روزت را آرام شروع کن؛ امروز هم فرصت تازه‌ای برای درخشیدن داری.';
    if (h < 15) return 'وسط شلوغی روز، چند دقیقه برای خودت نگه دار.';
    if (h < 19) return 'به چیزهایی که امروز از پسشان برآمدی افتخار کن.';
    return 'همه‌چیز لازم نیست امشب حل شود؛ با خیال راحت استراحت کن.';
  }

  @override
  Widget build(BuildContext context) {
    final c = colorsFor(theme);
    final now = DateTime.now();
    final pinned = notes.where((n) => n.pinned).take(3).toList();
    final fav = notes.where((n) => n.favorite).length;
    final reminders = notes.where((n) => n.reminderAt != null).length;
    final past = notes
        .where(
          (n) =>
              n.kind == NoteKind.memory &&
              n.createdAt.month == now.month &&
              n.createdAt.day == now.day &&
              n.createdAt.year < now.year,
        )
        .toList();

    return ColoredBox(
      color: AppPalette.page,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 145),
          children: [
            _Reveal(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          greeting() + ' ❤️',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          DateFormat('d MMMM yyyy', 'fa').format(now),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: .48),
                          ),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () => onNavigate(5),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                CloudService.instance.online ? Icons.sync_rounded : Icons.cloud_off_rounded,
                                size: 15,
                                color: CloudService.instance.online ? c.primary : Colors.white38,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                CloudService.instance.configured
                                    ? (CloudService.instance.online ? 'دفتر دوطرفه • آنلاین' : 'دفتر دوطرفه • آفلاین')
                                    : 'دفتر دوطرفه • راه‌اندازی نشده',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: CloudService.instance.online ? c.primary : Colors.white38,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  _BreathingLogo(color: c.primary),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _Reveal(
              delay: const Duration(milliseconds: 120),
              child: _Glass(
                accent: c.primary,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.auto_awesome_rounded, color: c.primary),
                        const SizedBox(width: 9),
                        const Text(
                          'جمله امروز',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      '«${quotes[quoteIndex % quotes.length]}»',
                      style: const TextStyle(
                        fontSize: 19,
                        height: 1.55,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'هر ۲۴ ساعت یک جمله‌ی تازه برایت انتخاب می‌شود ✨',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .45),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _stat(
                  '${notes.length}',
                  'یادداشت',
                  Icons.sticky_note_2_rounded,
                  c.primary,
                ),
                const SizedBox(width: 10),
                _stat(
                  '$fav',
                  'محبوب',
                  Icons.favorite_rounded,
                  Colors.pinkAccent,
                ),
                const SizedBox(width: 10),
                _stat(
                  '$reminders',
                  'یادآوری',
                  Icons.notifications_active_rounded,
                  Colors.amber,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _Reveal(
              delay: const Duration(milliseconds: 180),
              child: _Glass(
                accent: c.secondary,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'پیام همین ساعت',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _timeLine(greeting(), _messageForHour(), c.primary),
                    const SizedBox(height: 10),
                    //  Text(
                    // 'صبح بخیر آبجی بزرگم ☀️ • ظهر بخیر خواهر بزرگم 🌤️ • عصر بخیر آبجی ❤️ • شب بخیر خواهرم 🌙',
                    // style: TextStyle(
                    //     color: Colors.white.withValues(alpha: .48),
                    //     fontSize: 12,
                    //   ),
                    //  ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _Reveal(
              delay: const Duration(milliseconds: 260),
              child: Row(
                children: [
                  Expanded(
                    child: _quick(
                      'یادداشت',
                      Icons.edit_note_rounded,
                      c.primary,
                      onNew,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _quick(
                      'خاطره',
                      Icons.photo_library_rounded,
                      c.secondary,
                      () => onNavigate(3),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _quick(
                      'نامه',
                      Icons.mail_rounded,
                      c.accent,
                      () => onNavigate(4),
                    ),
                  ),
                ],
              ),
            ),
            if (past.isNotEmpty) ...[
              const SizedBox(height: 20),
              _Reveal(
                child: _Glass(
                  accent: Colors.amber,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.history_rounded,
                            color: Colors.amber,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'امروز در گذشته',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 17,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'خاطرات سال‌های قبل همین روز را دوباره ببین.',
                        style: TextStyle(color: Colors.white54),
                      ),
                      const SizedBox(height: 10),
                      ...past
                          .take(3)
                          .map(
                            (n) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              onTap: () => onOpenNote(n),
                              leading: CircleAvatar(
                                backgroundColor: Colors.amber.withValues(
                                  alpha: .1,
                                ),
                                child: const Icon(
                                  Icons.favorite_rounded,
                                  color: Colors.amber,
                                ),
                              ),
                              title: Text(
                                n.title.isEmpty ? 'بدون عنوان' : n.title,
                              ),
                              subtitle: Text(
                                n.body,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
              ),
            ],
            if (pinned.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text(
                'سنجاق‌شده‌ها',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
              ),
              const SizedBox(height: 9),
              ...pinned.map(
                (n) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _Glass(
                    accent: Colors.amber,
                    onTap: () => onOpenNote(n),
                    child: Row(
                      children: [
                        const Icon(Icons.push_pin_rounded, color: Colors.amber),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            n.title.isEmpty ? 'بدون عنوان' : n.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (n.favorite)
                          const Icon(
                            Icons.favorite_rounded,
                            color: Colors.pinkAccent,
                            size: 18,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _stat(String value, String label, IconData icon, Color color) =>
      Expanded(
        child: _Glass(
          accent: color,
          child: Column(
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 7),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .42),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      );

  Widget _timeLine(String title, String text, Color color) => Row(
    children: [
      Icon(Icons.favorite_border_rounded, color: color),
      const SizedBox(width: 9),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            Text(
              text,
              style: TextStyle(color: Colors.white.withValues(alpha: .62)),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _quick(String title, IconData icon, Color color, VoidCallback onTap) =>
      _Glass(
        accent: color,
        onTap: onTap,
        child: Column(
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 7),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
      );
}

class NotesTab extends StatefulWidget {
  const NotesTab({
    super.key,
    required this.notes,
    required this.theme,
    required this.onOpen,
    required this.onDelete,
    required this.onRefresh,
  });
  final List<NoteItem> notes;
  final AppThemeChoice theme;
  final ValueChanged<NoteItem> onOpen;
  final ValueChanged<NoteItem> onDelete;
  final ValueChanged<NoteItem> onRefresh;
  @override
  State<NotesTab> createState() => _NotesTabState();
}

class _NotesTabState extends State<NotesTab> {
  String query = '';
  NoteFolder? folder;
  String? tag;
  String sort = 'جدیدترین';

  List<NoteItem> get filtered {
    final q = query.trim().toLowerCase();
    final list = widget.notes.where((n) {
      final hit =
          q.isEmpty ||
          '${n.title} ${n.body} ${n.folder.label}'.toLowerCase().contains(q) ||
          n.tags.any((t) => t.toLowerCase().contains(q));
      return hit &&
          (folder == null || n.folder == folder) &&
          (tag == null || n.tags.contains(tag)) &&
          !n.inTrash;
    }).toList();
    list.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      return sort == 'قدیمی‌ترین'
          ? a.updatedAt.compareTo(b.updatedAt)
          : b.updatedAt.compareTo(a.updatedAt);
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final c = colorsFor(widget.theme);
    final tags = widget.notes.expand((e) => e.tags).toSet().toList();
    return ColoredBox(
      color: AppPalette.page,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
              child: Column(
                children: [
                  const Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'یادداشت‌های من',
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    onChanged: (v) => setState(() => query = v),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search_rounded),
                      hintText: 'عنوان، متن، پوشه یا Tag...',
                    ),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _chip(
                          'همه',
                          folder == null,
                          () => setState(() => folder = null),
                          c.primary,
                        ),
                        ...NoteFolder.values.map(
                          (f) => _chip(
                            f.label,
                            folder == f,
                            () => setState(() => folder = f),
                            c.primary,
                          ),
                        ),
                        if (tags.isNotEmpty)
                          ...tags.map(
                            (t) => _chip(
                              '#$t',
                              tag == t,
                              () => setState(() => tag = tag == t ? null : t),
                              c.secondary,
                            ),
                          ),
                        _chip(sort, false, _sortMenu, c.accent),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.search_off_rounded,
                            size: 62,
                            color: c.primary.withValues(alpha: .5),
                          ),
                          const SizedBox(height: 10),
                          const Text('یادداشتی پیدا نشد'),
                          const SizedBox(height: 6),
                          const Text(
                            'از جست‌وجو یا پوشه دیگری استفاده کن.',
                            style: TextStyle(color: Colors.white54),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(18, 8, 18, 145),
                      itemCount: filtered.length,
                      itemBuilder: (context, i) {
                        final n = filtered[i];
                        return _Reveal(
                          delay: Duration(milliseconds: i * 35),
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Dismissible(
                              key: ValueKey(n.id),
                              direction: DismissDirection.endToStart,
                              confirmDismiss: (_) async {
                                widget.onDelete(n);
                                return true;
                              },
                              background: Container(
                                decoration: BoxDecoration(
                                  color: Colors.redAccent.withValues(
                                    alpha: .16,
                                  ),
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 24),
                                child: const Icon(
                                  Icons.delete_outline_rounded,
                                  color: Colors.redAccent,
                                ),
                              ),
                              child: _NoteCard(
                                note: n,
                                color: c.primary,
                                onTap: () => widget.onOpen(n),
                                onDelete: () => widget.onDelete(n),
                                onRefresh: () => widget.onRefresh(n),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap, Color color) =>
      Padding(
        padding: const EdgeInsets.only(left: 6),
        child: FilterChip(
          selected: selected,
          label: Text(label),
          onSelected: (_) => onTap(),
          showCheckmark: false,
          avatar: selected
              ? Icon(Icons.check_rounded, size: 14, color: color)
              : null,
        ),
      );
  void _sortMenu() => showModalBottomSheet(
    context: context,
    backgroundColor: AppPalette.surface,
    builder: (_) => SafeArea(
      child: Wrap(
        children: ['جدیدترین', 'قدیمی‌ترین']
            .map(
              (s) => ListTile(
                leading: Icon(
                  s == sort
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                ),
                title: Text(s),
                onTap: () {
                  setState(() => sort = s);
                  Navigator.pop(context);
                },
              ),
            )
            .toList(),
      ),
    ),
  );
}

class _NoteCard extends StatefulWidget {
  const _NoteCard({
    required this.note,
    required this.color,
    required this.onTap,
    required this.onDelete,
    required this.onRefresh,
  });
  final NoteItem note;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onRefresh;
  @override
  State<_NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends State<_NoteCard> {
  bool down = false;

  @override
  Widget build(BuildContext context) {
    final n = widget.note;
    return GestureDetector(
      onTapDown: (_) => setState(() => down = true),
      onTapCancel: () => setState(() => down = false),
      onTapUp: (_) {
        setState(() => down = false);
        widget.onTap();
      },
      child: AnimatedScale(
        scale: down ? .985 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: _Glass(
          accent: widget.color,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      n.title.isEmpty ? 'بدون عنوان' : n.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                      ),
                    ),
                  ),
                  if (n.pinned)
                    const Icon(
                      Icons.push_pin_rounded,
                      color: Colors.amber,
                      size: 18,
                    ),
                  if (n.favorite)
                    const Padding(
                      padding: EdgeInsets.only(left: 6),
                      child: Icon(
                        Icons.favorite_rounded,
                        color: Colors.pinkAccent,
                        size: 18,
                      ),
                    ),
                  if (n.reminderAt != null)
                    const Padding(
                      padding: EdgeInsets.only(left: 6),
                      child: Icon(
                        Icons.notifications_active_rounded,
                        color: Colors.amber,
                        size: 17,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (n.kind == NoteKind.checklist) _checkPreview(n),
              if (n.kind != NoteKind.checklist && n.body.isNotEmpty)
                Text(
                  _stripMarkup(n.body),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: n.textSize,
                    height: 1.45,
                    color: Colors.white.withValues(alpha: .72),
                  ),
                ),
              if (n.imagePaths.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: SizedBox(
                    height: 95,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: math.min(n.imagePaths.length, 4),
                      separatorBuilder: (_, __) => const SizedBox(width: 7),
                      itemBuilder: (_, i) => ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: Image.file(
                          File(n.imagePaths[i]),
                          width: 95,
                          height: 95,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ),
              if (n.audioPath != null)
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Row(
                    children: [
                      Icon(
                        Icons.graphic_eq_rounded,
                        color: Colors.white54,
                        size: 18,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'یادداشت صوتی',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 9),
              Wrap(
                spacing: 7,
                runSpacing: 5,
                children: [
                  _tagPill(n.folder.label, widget.color),
                  ...n.tags.take(3).map((t) => _tagPill('#$t', Colors.white54)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                DateFormat('yyyy/MM/dd • HH:mm').format(n.updatedAt),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .33),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _checkPreview(NoteItem n) => Column(
    children: n.checkItems
        .take(4)
        .map(
          (e) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Icon(
                  e.done
                      ? Icons.check_box_rounded
                      : Icons.check_box_outline_blank_rounded,
                  size: 18,
                  color: e.done ? widget.color : Colors.white38,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    e.text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        )
        .toList(),
  );

  Widget _tagPill(String t, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: c.withValues(alpha: .09),
      borderRadius: BorderRadius.circular(50),
    ),
    child: Text(
      t,
      style: TextStyle(fontSize: 10, color: c, fontWeight: FontWeight.w700),
    ),
  );
  String _stripMarkup(String v) =>
      v.replaceAll('**', '').replaceAll('__', '').replaceAll('_', '');
}

class MemoriesTab extends StatefulWidget {
  const MemoriesTab({
    super.key,
    required this.notes,
    required this.theme,
    required this.onOpen,
    required this.onDelete,
    required this.onRefresh,
  });
  final List<NoteItem> notes;
  final AppThemeChoice theme;
  final ValueChanged<NoteItem> onOpen;
  final ValueChanged<NoteItem> onDelete;
  final ValueChanged<NoteItem> onRefresh;
  @override
  State<MemoriesTab> createState() => _MemoriesTabState();
}

class _MemoriesTabState extends State<MemoriesTab> {
  bool calendar = false;
  @override
  Widget build(BuildContext context) {
    final c = colorsFor(widget.theme);
    final memories =
        widget.notes
            .where((e) => e.kind == NoteKind.memory && !e.inTrash)
            .toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'خاطره‌ها',
                    style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => calendar = !calendar),
                  icon: Icon(
                    calendar
                        ? Icons.grid_view_rounded
                        : Icons.calendar_month_rounded,
                    color: c.primary,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: calendar
                ? _MemoryCalendar(
                    notes: memories,
                    color: c.primary,
                    onOpen: widget.onOpen,
                  )
                : memories.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.photo_library_outlined,
                          size: 64,
                          color: c.primary.withValues(alpha: .45),
                        ),
                        const SizedBox(height: 12),
                        const Text('هنوز خاطره‌ای ثبت نشده'),
                        const SizedBox(height: 6),
                        const Text(
                          'یک عکس و چند کلمه می‌تواند یک روز را ماندگار کند.',
                          style: TextStyle(color: Colors.white54),
                        ),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 145),
                    itemCount: memories.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: .80,
                        ),
                    itemBuilder: (context, i) {
                      final n = memories[i];
                      return _Reveal(
                        delay: Duration(milliseconds: i * 30),
                        child: _MemoryCard(
                          note: n,
                          color: c.primary,
                          onTap: () => widget.onOpen(n),
                          onDelete: () => widget.onDelete(n),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _MemoryCard extends StatelessWidget {
  const _MemoryCard({
    required this.note,
    required this.color,
    required this.onTap,
    required this.onDelete,
  });
  final NoteItem note;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف خاطره'),
        content: const Text('این خاطره به سطل زباله منتقل شود؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('لغو'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) onDelete();
  }

  @override
  Widget build(BuildContext context) {
    final p = note.imagePaths.isNotEmpty ? note.imagePaths.first : null;
    final hasImage = p != null && File(p).existsSync();
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppPalette.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: .05)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .25),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned.fill(
              child: hasImage
                  ? Image.file(File(p), fit: BoxFit.cover)
                  : Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            color.withValues(alpha: .13),
                            Colors.white.withValues(alpha: .03),
                          ],
                        ),
                      ),
                      child: Icon(
                        Icons.photo_rounded,
                        size: 52,
                        color: color.withValues(alpha: .4),
                      ),
                    ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: .82),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 7,
              left: 7,
              right: 7,
              child: Row(
                children: [
                  IconButton(
                    onPressed: onTap,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black54,
                    ),
                    icon: const Icon(Icons.edit_rounded, size: 18),
                  ),
                  const Spacer(),
                  if (note.favorite)
                    const Icon(
                      Icons.favorite_rounded,
                      color: Colors.pinkAccent,
                      size: 18,
                    ),
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: () => _confirmDelete(context),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black54,
                    ),
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.redAccent,
                      size: 19,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      note.title.isEmpty ? 'خاطره' : note.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    if (note.body.isNotEmpty)
                      Text(
                        note.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          height: 1.35,
                        ),
                      ),
                    const SizedBox(height: 5),
                    Text(
                      DateFormat('yyyy/MM/dd').format(note.createdAt),
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemoryCalendar extends StatelessWidget {
  const _MemoryCalendar({
    required this.notes,
    required this.color,
    required this.onOpen,
  });
  final List<NoteItem> notes;
  final Color color;
  final ValueChanged<NoteItem> onOpen;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final first = DateTime(now.year, now.month, 1);
    final days = DateTime(now.year, now.month + 1, 0).day;
    final offset = first.weekday % 7;
    final totalCells = offset + days;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 145),
      children: [
        Text(
          DateFormat('MMMM yyyy', 'fa').format(now),
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        _Glass(
          accent: color,
          child: Column(
            children: [
              Row(
                children: ['ش', 'ی', 'د', 'س', 'چ', 'پ', 'ج']
                    .map(
                      (d) => Expanded(
                        child: Center(
                          child: Text(
                            d,
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 10),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: totalCells,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  crossAxisSpacing: 6,
                  mainAxisSpacing: 6,
                  childAspectRatio: 1.0,
                ),
                itemBuilder: (context, index) {
                  if (index < offset) return const SizedBox();
                  final day = index - offset + 1;
                  final date = DateTime(now.year, now.month, day);
                  final matches = notes
                      .where(
                        (n) =>
                            n.createdAt.year == date.year &&
                            n.createdAt.month == date.month &&
                            n.createdAt.day == date.day,
                      )
                      .toList();
                  final hasMemory = matches.isNotEmpty;
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: hasMemory ? () => onOpen(matches.first) : null,
                      borderRadius: BorderRadius.circular(16),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        decoration: BoxDecoration(
                          color: hasMemory
                              ? color.withValues(alpha: .14)
                              : const Color(0xFF080D16),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: hasMemory
                                ? color.withValues(alpha: .45)
                                : Colors.white.withValues(alpha: .055),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '$day',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: hasMemory ? color : Colors.white70,
                              ),
                            ),
                            if (hasMemory) ...[
                              const SizedBox(height: 2),
                              Icon(
                                Icons.favorite_rounded,
                                size: 11,
                                color: color,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _Glass(
          accent: color,
          child: Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: color),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  notes.isEmpty
                      ? 'هنوز خاطره‌ای برای این ماه ثبت نشده.'
                      : '${notes.length} خاطره در دفترت ثبت شده است.',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class LettersTab extends StatefulWidget {
  const LettersTab({super.key, required this.theme, required this.onUse});
  final AppThemeChoice theme;
  final Future<void> Function(String title, String text) onUse;
  @override
  State<LettersTab> createState() => _LettersTabState();
}

class _LettersTabState extends State<LettersTab> {
  String query = '';
  @override
  Widget build(BuildContext context) {
    final c = colorsFor(widget.theme);
    final entries = letterTemplates.entries
        .where(
          (e) =>
              query.isEmpty || e.key.contains(query) || e.value.contains(query),
        )
        .toList();
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 145),
        children: [
          const Text(
            'نامه‌های مخصوص خواهرم ❤️',
            style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            'نامه را باز کن، ویرایشش کن و به یادداشت‌هایت اضافه کن.',
            style: TextStyle(color: Colors.white.withValues(alpha: .52)),
          ),
          const SizedBox(height: 12),
          TextField(
            onChanged: (v) => setState(() => query = v),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              hintText: 'جست‌وجوی نامه...',
            ),
          ),
          const SizedBox(height: 18),
          ...entries.asMap().entries.map(
            (entry) => _EnvelopeCard(
              index: entry.key,
              title: entry.value.key,
              text: entry.value.value,
              color: c.primary,
              onUse: () => widget.onUse(entry.value.key, entry.value.value),
            ),
          ),
        ],
      ),
    );
  }
}

class _EnvelopeCard extends StatefulWidget {
  const _EnvelopeCard({
    required this.index,
    required this.title,
    required this.text,
    required this.color,
    required this.onUse,
  });
  final int index;
  final String title;
  final String text;
  final Color color;
  final VoidCallback onUse;
  @override
  State<_EnvelopeCard> createState() => _EnvelopeCardState();
}

class _EnvelopeCardState extends State<_EnvelopeCard>
    with SingleTickerProviderStateMixin {
  bool open = false;
  late final AnimationController c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  void toggle() {
    setState(() => open = !open);
    if (open) {
      c.forward();
    } else {
      c.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: toggle,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: Duration(milliseconds: 300 + widget.index * 20),
          curve: Curves.easeOutCubic,
          builder: (_, v, child) => Transform.translate(
            offset: Offset(0, (1 - v) * 10),
            child: Opacity(opacity: v, child: child),
          ),
          child: _Glass(
            accent: widget.color,
            child: AnimatedSize(
              duration: const Duration(milliseconds: 420),
              curve: Curves.easeOutCubic,
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: widget.color.withValues(alpha: .10),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          open ? Icons.markunread_rounded : Icons.mail_rounded,
                          color: widget.color,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      Icon(
                        open
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                      ),
                    ],
                  ),
                  if (open) ...[
                    const SizedBox(height: 12),
                    Text(
                      widget.text,
                      style: const TextStyle(
                        height: 1.6,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.icon(
                        onPressed: widget.onUse,
                        icon: const Icon(Icons.save_rounded),
                        label: const Text('ذخیره در یادداشت‌ها'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SettingsTab extends StatefulWidget {
  const SettingsTab({
    super.key,
    required this.storage,
    required this.theme,
    required this.cloud,
    required this.trash,
    required this.onTheme,
    required this.onRefresh,
    required this.onLockChange,
  });
  final StorageService storage;
  final AppThemeChoice theme;
  final CloudService cloud;
  final List<NoteItem> trash;
  final ValueChanged<AppThemeChoice> onTheme;
  final VoidCallback onRefresh;
  final VoidCallback onLockChange;
  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  bool bio = false;
  bool lock = false;
  @override
  void initState() {
    super.initState();
    lock = widget.storage.loadPin() != null;
    bio = widget.storage.loadBiometric();
  }

  Future<void> togglePin() async {
    if (lock) {
      await widget.storage.clearPin();
      setState(() => lock = false);
      widget.onLockChange();
      return;
    }
    final ctl = TextEditingController();
    final v = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('قفل برنامه'),
        content: TextField(
          controller: ctl,
          keyboardType: TextInputType.number,
          obscureText: true,
          maxLength: 6,
          decoration: const InputDecoration(hintText: 'PIN چهار تا شش رقمی'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('لغو'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctl.text),
            child: const Text('ذخیره'),
          ),
        ],
      ),
    );
    ctl.dispose();
    if (v != null && v.length >= 4) {
      await widget.storage.savePin(v);
      setState(() => lock = true);
      widget.onLockChange();
    }
  }

  Future<void> toggleBio() async {
    final auth = LocalAuthentication();
    try {
      if (!await auth.isDeviceSupported()) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('بیومتریک روی این دستگاه پشتیبانی نمی‌شود.'),
            ),
          );
        return;
      }
      final available = await auth.getAvailableBiometrics();
      if (available.isEmpty) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'هیچ اثر انگشت یا روش بیومتریکی روی دستگاه ثبت نشده است. ابتدا آن را در تنظیمات گوشی فعال کن.',
              ),
            ),
          );
        return;
      }
      if (bio) {
        await widget.storage.saveBiometric(false);
        if (mounted) setState(() => bio = false);
        widget.onLockChange();
        return;
      }
      final ok = await auth.authenticate(
        localizedReason: 'برای فعال کردن قفل Big Sister Notes احراز هویت کن',
        biometricOnly: true,
        sensitiveTransaction: true,
        persistAcrossBackgrounding: true,
      );
      if (ok) {
        await widget.storage.saveBiometric(true);
        if (mounted) setState(() => bio = true);
        widget.onLockChange();
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('قفل بیومتریک فعال شد ❤️')),
          );
      }
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'احراز هویت انجام نشد. مطمئن شو اثر انگشت/Face Unlock روی گوشی فعال است.',
            ),
          ),
        );
    }
  }

  Future<void> backup() async {
    final json = await widget.storage.exportJson();
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/big_sister_backup_${DateTime.now().millisecondsSinceEpoch}.json',
    );
    await file.writeAsString(jsonEncode(json));
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        subject: 'Big Sister Notes Backup',
      ),
    );
  }

  Future<void> restore() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    final path = picked?.files.single.path;
    if (path == null) return;
    try {
      await widget.storage.importJson(
        jsonDecode(await File(path).readAsString()) as Map<String, dynamic>,
      );
      for (final note in widget.storage.activeNotes()) {
        if (note.reminderAt != null &&
            note.reminderAt!.isAfter(DateTime.now())) {
          await NotificationService.instance.scheduleNoteReminder(
            noteId: note.id,
            title: note.title,
            when: note.reminderAt!,
          );
        }
      }
      widget.onRefresh();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('پشتیبان کامل با موفقیت بازیابی شد ❤️')),
        );
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فایل پشتیبان معتبر نیست.')),
        );
    }
  }

  Future<void> deleteAllNotes() async {
    if (widget.storage.activeNotes().isEmpty) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('یادداشتی برای حذف وجود ندارد.')),
        );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('حذف همه یادداشت‌ها'),
        content: const Text(
          'همه یادداشت‌ها، خاطره‌ها، نامه‌ها و چک‌لیست‌ها به سطل زباله منتقل شوند؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('لغو'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(d, true),
            child: const Text('انتقال به سطل زباله'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final active = widget.storage.activeNotes();
    await widget.storage.moveAllToTrash();
    for (final n in active) {
      await NotificationService.instance.cancelNoteReminder(n.id);
    }
    widget.onRefresh();
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('همه موارد به سطل زباله منتقل شدند.')),
      );
  }

  @override
  Widget build(BuildContext context) {
    final c = colorsFor(widget.theme);
    final names = {
      AppThemeChoice.turquoise: 'فیروزه‌ای',
      AppThemeChoice.sky: 'آسمانی',
      AppThemeChoice.red: 'قرمز',
      AppThemeChoice.blue: 'آبی',
    };
    return ColoredBox(
      color: AppPalette.page,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 145),
          children: [
            const Text(
              'تنظیمات',
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 18),
            _Glass(
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: c.primary.withValues(alpha: .10),
                      child: Icon(Icons.favorite_rounded, color: c.primary),
                    ),
                    title: const Text(
                      'خواهر بزرگم ❤️',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    //subtitle: const Text(''),
                    //trailing: const Icon(Icons.lock_outline_rounded),
                  ),
                  const Divider(),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: lock,
                    onChanged: (_) => togglePin(),
                    secondary: Icon(Icons.lock_rounded, color: c.primary),
                    title: const Text('قفل PIN'),
                    subtitle: Text(
                      lock ? 'قفل PIN فعال است' : 'برای خصوصی‌تر شدن فعالش کن',
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: bio,
                    onChanged: (_) => toggleBio(),
                    secondary: Icon(
                      Icons.fingerprint_rounded,
                      color: c.secondary,
                    ),
                    title: const Text('قفل بیومتریک'),
                    subtitle: const Text('اثر انگشت یا روش بیومتریک دستگاه'),
                  ),
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.sync_rounded, color: c.primary),
                    title: const Text('دفتر مشترک من ↔ آبجی'),
                    subtitle: Text(
                      widget.cloud.configured
                          ? (widget.cloud.online ? 'همگام‌سازی زنده فعال است' : 'دفتر متصل است؛ اتصال لحظه‌ای برقرار نیست')
                          : 'یک ورود اولیه؛ بعد از آن نمایش و همگام‌سازی خودکار',
                    ),
                    trailing: Icon(Icons.chevron_left_rounded, color: c.primary),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CloudSharedLoginScreen(storage: widget.storage, theme: widget.theme),
                        ),
                      );
                      if (mounted) setState(() {});
                      widget.onRefresh();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _Glass(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'چهار تم دارک',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 13),
                  Row(
                    children: AppThemeChoice.values.map((e) {
                      final cc = colorsFor(e);
                      final selected = e == widget.theme;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: GestureDetector(
                            onTap: () => widget.onTheme(e),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 340),
                              curve: Curves.easeOutBack,
                              height: 92,
                              decoration: BoxDecoration(
                                color: cc.primary.withValues(
                                  alpha: selected ? .15 : .06,
                                ),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: selected
                                      ? cc.primary
                                      : Colors.white.withValues(alpha: .06),
                                  width: selected ? 2 : 1,
                                ),
                                boxShadow: selected
                                    ? [
                                        BoxShadow(
                                          color: cc.primary.withValues(
                                            alpha: .16,
                                          ),
                                          blurRadius: 22,
                                        ),
                                      ]
                                    : const [],
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        colors: [
                                          cc.primary,
                                          cc.secondary,
                                          cc.accent,
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 7),
                                  Text(
                                    names[e]!,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _Glass(
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.calendar_month_rounded,
                      color: c.primary,
                    ),
                    title: const Text('تقویم خاطرات'),
                    subtitle: const Text('تمام خاطره‌ها را بر اساس روز ببین'),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CalendarFullScreen(
                          storage: widget.storage,
                          theme: widget.theme,
                        ),
                      ),
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.delete_sweep_rounded,
                      color: Colors.redAccent,
                    ),
                    title: Text('سطل زباله (${widget.trash.length})'),
                    subtitle: const Text('بازیابی یا حذف دائمی یادداشت‌ها'),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TrashScreen(
                          storage: widget.storage,
                          theme: widget.theme,
                          onRefresh: widget.onRefresh,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _Glass(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.favorite_rounded, color: c.primary),
                title: const Text('برای خواهرم ❤️🫂'),
                subtitle: const Text('نامه‌ها و جمله‌هایی که مخصوص او هستند'),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SisterSpaceScreen(
                      storage: widget.storage,
                      theme: widget.theme,
                      onSaved: widget.onRefresh,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            _Glass(
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.backup_rounded, color: c.primary),
                    title: const Text('پشتیبان‌گیری کامل'),
                    subtitle: const Text('یادداشت، عکس، صدا، Tag و تنظیمات'),
                    onTap: backup,
                  ),
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.restore_rounded, color: c.primary),
                    title: const Text('بازیابی پشتیبان'),
                    subtitle: const Text('فایل JSON پشتیبان را وارد کن'),
                    onTap: restore,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _Glass(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.delete_sweep_rounded,
                  color: Colors.redAccent,
                ),
                title: const Text('حذف همه موارد'),
                subtitle: const Text(
                  'همه یادداشت‌ها، خاطره‌ها، نامه‌ها و چک‌لیست‌ها را به سطل زباله منتقل کن',
                ),
                onTap: deleteAllNotes,
              ),
            ),
            const SizedBox(height: 14),
            _Glass(
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.bar_chart_rounded, color: c.primary),
                    title: const Text('آمار و فعالیت'),
                    subtitle: const Text(
                      'تعداد یادداشت‌ها، نامه‌ها، خاطره‌ها و صوت‌ها',
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StatsScreen(
                          storage: widget.storage,
                          theme: widget.theme,
                        ),
                      ),
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.picture_as_pdf_rounded,
                      color: c.secondary,
                    ),
                    title: const Text('خروجی و اشتراک‌گذاری'),
                    subtitle: const Text('TXT و PDF برای یادداشت‌ها'),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ExportScreen(
                          storage: widget.storage,
                          theme: widget.theme,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _Glass(
              child: Column(
                children: [
                  Icon(Icons.favorite_rounded, size: 42, color: c.primary),
                  const SizedBox(height: 9),
                  const Text(
                    'For Big Sister ❤️🫂',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 7),
                  const Text(
                    'یک دفتر امن برای حرف‌هایی که شاید همیشه فرصت گفتنشان را نداری.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54, height: 1.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SisterSpaceScreen extends StatelessWidget {
  const SisterSpaceScreen({
    super.key,
    required this.storage,
    required this.theme,
    this.onSaved,
  });

  final StorageService storage;
  final AppThemeChoice theme;
  final VoidCallback? onSaved;

  Future<void> _saveHeartLine(
    BuildContext context,
    String title,
    String text,
  ) async {
    final now = DateTime.now();
    final note = NoteItem(
      id: now.microsecondsSinceEpoch.toString(),
      title: title,
      body: text,
      createdAt: now,
      updatedAt: now,
      kind: NoteKind.letter,
      folder: NoteFolder.letters,
      tags: const ['خواهر'],
      favorite: true,
    );
    await storage.upsert(note);
    onSaved?.call();
    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('در نامه‌های تو ذخیره شد ❤️')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = colorsFor(theme);
    final custom = storage
        .activeNotes()
        .where(
          (n) =>
              n.folder == NoteFolder.letters ||
              n.tags.any((t) => t.contains('خواهر')),
        )
        .toList();
    final lines = <Map<String, dynamic>>[
      {
        'title': 'چرا دوستت دارم',
        'icon': Icons.favorite_rounded,
        'color': Colors.pinkAccent,
        'text':
            'بودنت برای من یک حس امن است؛ لازم نیست دلیل بزرگی برای دوست داشتنت داشته باشم.',
      },
      {
        'title': 'چیزهایی که بابتشان ممنونم',
        'icon': Icons.volunteer_activism_rounded,
        'color': Colors.amber,
        'text':
            'ممنون که در زندگی من هستی؛ برای لحظه‌های خوب، حرف‌ها و آغوش‌هایت.',
      },
      {
        'title': 'وقتی دلم برایت تنگ می‌شود',
        'icon': Icons.nightlight_rounded,
        'color': c.secondary,
        'text': 'گاهی فقط یاد تو کافی است تا یک روز معمولی کمی گرم‌تر شود.',
      },
      {
        'title': 'آرزوهایی که برایت دارم',
        'icon': Icons.auto_awesome_rounded,
        'color': c.primary,
        'text':
            'آرامش، سلامتی، لبخندهای واقعی و روزهایی که به خودت افتخار کنی.',
      },
      {
        'title': 'من به تو افتخار می‌کنم',
        'icon': Icons.star_rounded,
        'color': Colors.orangeAccent,
        'text':
            'مهم نیست چقدر مسیر سخت بوده؛ دوباره ایستادن تو برای من ارزشمند است.',
      },
      {
        'title': 'اگر امروز سخت بود',
        'icon': Icons.cloud_done_rounded,
        'color': Colors.lightBlueAccent,
        'text':
            'امروز را لازم نیست کامل کنی. نفس بکش، کمی استراحت کن و فقط قدم بعدی را بردار.',
      },
    ];

    return Scaffold(
      backgroundColor: AppPalette.page,
      appBar: AppBar(title: const Text('برای خواهرم ❤️🫂')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
        children: [
          _Reveal(
            child: _Glass(
              accent: c.primary,
              child: Column(
                children: [
                  const _BreathingLogo(color: Color(0xFFFF4D67)),
                  const SizedBox(height: 12),
                  const Text(
                    'این بخش فقط برای توست، خواهر بزرگم.',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'هر وقت دلت خواست، یکی از این جمله‌ها را باز کن.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .55),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ...lines.asMap().entries.map((entry) {
            final i = entry.key;
            final item = entry.value;
            final itemColor = item['color'] as Color;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _Reveal(
                delay: Duration(milliseconds: i * 55),
                child: _Glass(
                  accent: itemColor,
                  onTap: () => showModalBottomSheet(
                    context: context,
                    backgroundColor: AppPalette.surface,
                    showDragHandle: true,
                    builder: (_) => SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              item['icon'] as IconData,
                              size: 42,
                              color: itemColor,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              item['title'] as String,
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              item['text'] as String,
                              style: const TextStyle(
                                fontSize: 16,
                                height: 1.7,
                                color: Colors.white70,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 18),
                            FilledButton.icon(
                              onPressed: () => _saveHeartLine(
                                context,
                                item['title'] as String,
                                item['text'] as String,
                              ),
                              icon: const Icon(Icons.favorite_rounded),
                              label: const Text('ذخیره در نامه‌ها'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: itemColor.withValues(alpha: .12),
                        child: Icon(item['icon'] as IconData, color: itemColor),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          item['title'] as String,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.chevron_left_rounded,
                        color: Colors.white38,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          if (custom.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text(
              'نامه‌ها و یادداشت‌های مخصوص او',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            ...custom
                .take(8)
                .map(
                  (n) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _Glass(
                      accent: c.secondary,
                      child: Row(
                        children: [
                          Icon(Icons.mail_rounded, color: c.secondary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              n.title.isEmpty ? 'نامه بدون عنوان' : n.title,
                            ),
                          ),
                          const Icon(
                            Icons.favorite_rounded,
                            color: Colors.pinkAccent,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}

class CalendarFullScreen extends StatelessWidget {
  const CalendarFullScreen({
    super.key,
    required this.storage,
    required this.theme,
  });
  final StorageService storage;
  final AppThemeChoice theme;
  @override
  Widget build(BuildContext context) {
    final c = colorsFor(theme);
    return Scaffold(
      backgroundColor: AppPalette.page,
      appBar: AppBar(
        title: const Text('تقویم خاطرات'),
        backgroundColor: AppPalette.page,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
      ),
      body: ColoredBox(
        color: AppPalette.page,
        child: Stack(
          fit: StackFit.expand,
          children: [
            IgnorePointer(
              child: CustomPaint(
                painter: _CalendarAmbientPainter(c.primary, c.secondary),
              ),
            ),
            _MemoryCalendar(
              notes: storage
                  .activeNotes()
                  .where((e) => e.kind == NoteKind.memory)
                  .toList(),
              color: c.primary,
              onOpen: (n) => showModalBottomSheet(
                context: context,
                backgroundColor: AppPalette.surface,
                barrierColor: Colors.black.withValues(alpha: .65),
                builder: (_) => NoteReader(
                  note: n,
                  color: c.primary,
                  onDelete: () async {
                    await storage.moveToTrash(n.id);
                    await NotificationService.instance.cancelNoteReminder(n.id);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarAmbientPainter extends CustomPainter {
  const _CalendarAmbientPainter(this.primary, this.secondary);
  final Color primary;
  final Color secondary;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final points = [
      Offset(size.width * .10, size.height * .18),
      Offset(size.width * .88, size.height * .36),
      Offset(size.width * .30, size.height * .82),
    ];
    final colors = [primary, secondary, primary];
    for (var i = 0; i < points.length; i++) {
      paint.color = colors[i].withValues(alpha: .025);
      canvas.drawCircle(points[i], 150, paint);
      paint.color = colors[i].withValues(alpha: .012);
      canvas.drawCircle(points[i], 260, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CalendarAmbientPainter oldDelegate) =>
      oldDelegate.primary != primary || oldDelegate.secondary != secondary;
}

class TrashScreen extends StatefulWidget {
  const TrashScreen({
    super.key,
    required this.storage,
    required this.theme,
    required this.onRefresh,
  });
  final StorageService storage;
  final AppThemeChoice theme;
  final VoidCallback onRefresh;
  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  late List<NoteItem> list;
  @override
  void initState() {
    super.initState();
    list = widget.storage.trashNotes();
  }

  void reload() {
    setState(() => list = widget.storage.trashNotes());
    widget.onRefresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.page,
      appBar: AppBar(title: const Text('سطل زباله')),
      body: list.isEmpty
          ? const Center(child: Text('سطل زباله خالی است.'))
          : ListView.builder(
              padding: const EdgeInsets.all(18),
              itemCount: list.length,
              itemBuilder: (_, i) {
                final n = list[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _Glass(
                    accent: Colors.redAccent,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          n.title.isEmpty ? 'بدون عنوان' : n.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'حذف شده: ${DateFormat('yyyy/MM/dd HH:mm').format(n.deletedAt!)}',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  await widget.storage.restore(n.id);
                                  if (n.reminderAt != null) {
                                    await NotificationService.instance
                                        .scheduleNoteReminder(
                                          noteId: n.id,
                                          title: n.title,
                                          when: n.reminderAt!,
                                        );
                                  }
                                  reload();
                                },
                                icon: const Icon(Icons.restore_rounded),
                                label: const Text('بازیابی'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FilledButton.tonalIcon(
                                onPressed: () async {
                                  await widget.storage.deleteForever(n.id);
                                  reload();
                                },
                                icon: const Icon(Icons.delete_forever_rounded),
                                label: const Text('حذف دائمی'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key, required this.storage, required this.theme});
  final StorageService storage;
  final AppThemeChoice theme;
  @override
  Widget build(BuildContext context) {
    final notes = storage.activeNotes();
    final c = colorsFor(theme);
    final types = <String, int>{
      'یادداشت': notes.where((e) => e.kind == NoteKind.note).length,
      'چک‌لیست': notes.where((e) => e.kind == NoteKind.checklist).length,
      'نامه': notes.where((e) => e.kind == NoteKind.letter).length,
      'خاطره': notes.where((e) => e.kind == NoteKind.memory).length,
    };
    return Scaffold(
      backgroundColor: AppPalette.page,
      appBar: AppBar(title: const Text('آمار و فعالیت')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          _Glass(
            accent: c.primary,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _bigStat('${notes.length}', 'کل', c.primary),
                _bigStat(
                  '${notes.where((e) => e.favorite).length}',
                  'محبوب',
                  Colors.pinkAccent,
                ),
                _bigStat(
                  '${notes.where((e) => e.audioPath != null).length}',
                  'صوتی',
                  c.secondary,
                ),
                _bigStat(
                  '${notes.where((e) => e.tags.isNotEmpty).length}',
                  'Tag',
                  Colors.amber,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _Glass(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'بر اساس نوع',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
                ),
                const SizedBox(height: 12),
                ...types.entries.map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Expanded(child: Text(e.key)),
                        Text(
                          '${e.value}',
                          style: TextStyle(
                            color: c.primary,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Widget _bigStat(String v, String l, Color c) => Column(
  children: [
    Text(
      v,
      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: c),
    ),
    const SizedBox(height: 3),
    Text(l, style: const TextStyle(color: Colors.white54, fontSize: 10)),
  ],
);

class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key, required this.storage, required this.theme});
  final StorageService storage;
  final AppThemeChoice theme;
  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  bool busy = false;
  List<NoteItem> get all => widget.storage.activeNotes();
  Future<void> exportTxt() async {
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/big_sister_notes.txt');
    final b = all
        .map(
          (n) =>
              '===== ${n.title.isEmpty ? 'بدون عنوان' : n.title} =====\n${n.body}\nتاریخ: ${n.updatedAt}\nTag: ${n.tags.join(', ')}\n',
        )
        .join('\n');
    await f.writeAsString(b);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(f.path)], subject: 'Big Sister Notes'),
    );
  }

  Future<void> exportPdf() async {
    setState(() => busy = true);
    try {
      final doc = pw.Document();
      for (final n in all) {
        doc.addPage(
          pw.Page(
            build: (_) => pw.Padding(
              padding: const pw.EdgeInsets.all(30),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    n.title.isEmpty ? 'Big Sister Note' : n.title,
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 15),
                  pw.Text(n.body),
                  pw.SizedBox(height: 20),
                  pw.Text(
                    'Created: ${n.createdAt.toIso8601String()}',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                  pw.Text(
                    'Tags: ${n.tags.join(', ')}',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ],
              ),
            ),
          ),
        );
      }
      await Printing.sharePdf(
        bytes: await doc.save(),
        filename: 'big_sister_notes.pdf',
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = colorsFor(widget.theme);
    return Scaffold(
      backgroundColor: AppPalette.page,
      appBar: AppBar(title: const Text('خروجی و اشتراک‌گذاری')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          _Glass(
            accent: c.primary,
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.text_snippet_rounded, color: c.primary),
                  title: const Text('خروجی TXT'),
                  subtitle: const Text(
                    'متن تمام یادداشت‌ها را به اشتراک بگذار',
                  ),
                  onTap: busy ? null : exportTxt,
                ),
                const Divider(),
                ListTile(
                  leading: Icon(
                    Icons.picture_as_pdf_rounded,
                    color: c.secondary,
                  ),
                  title: const Text('خروجی PDF'),
                  subtitle: const Text('یادداشت‌ها را به‌صورت PDF آماده کن'),
                  onTap: busy ? null : exportPdf,
                ),
              ],
            ),
          ),
          if (busy)
            const Padding(
              padding: EdgeInsets.all(18),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}

class NoteEditorScreen extends StatefulWidget {
  const NoteEditorScreen({
    super.key,
    required this.storage,
    required this.theme,
    this.initial,
    this.initialKind,
    this.onDelete,
  });
  final StorageService storage;
  final AppThemeChoice theme;
  final NoteItem? initial;
  final NoteKind? initialKind;
  final Future<void> Function()? onDelete;
  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late final TextEditingController title;
  late final TextEditingController body;
  late NoteKind kind;
  late NoteFolder folder;
  late List<String> tags;
  late List<String> images;
  String? audioPath;
  DateTime? reminder;
  bool favorite = false,
      pinned = false,
      bold = false,
      italic = false,
      underline = false;
  double textSize = 17;
  List<CheckItem> checks = [];
  final ImagePicker picker = ImagePicker();
  final AudioRecorder recorder = AudioRecorder();
  final AudioPlayer player = AudioPlayer();
  bool recording = false;
  bool playing = false;
  Duration audioDuration = Duration.zero;
  Duration audioPosition = Duration.zero;
  @override
  void initState() {
    super.initState();
    final n = widget.initial;
    title = TextEditingController(text: n?.title ?? '');
    body = TextEditingController(text: n?.body ?? '');
    kind = n?.kind ?? widget.initialKind ?? NoteKind.note;
    folder =
        n?.folder ??
        (kind == NoteKind.memory
            ? NoteFolder.memories
            : kind == NoteKind.letter
            ? NoteFolder.letters
            : NoteFolder.personal);
    tags = List<String>.from(n?.tags ?? []);
    images = List<String>.from(n?.imagePaths ?? []);
    audioPath = n?.audioPath;
    reminder = n?.reminderAt;
    favorite = n?.favorite ?? false;
    pinned = n?.pinned ?? false;
    checks =
        n?.checkItems
            .map((e) => CheckItem(text: e.text, done: e.done))
            .toList() ??
        [];
    textSize = n?.textSize ?? 17;
    bold = n?.bold ?? false;
    italic = n?.italic ?? false;
    underline = n?.underline ?? false;
    player.onDurationChanged.listen((d) {
      if (mounted) setState(() => audioDuration = d);
    });
    player.onPositionChanged.listen((d) {
      if (mounted) setState(() => audioPosition = d);
    });
    player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => playing = false);
    });
  }

  @override
  void dispose() {
    title.dispose();
    body.dispose();
    recorder.dispose();
    player.dispose();
    super.dispose();
  }

  Future<void> pickImages() async {
    final xs = await picker.pickMultiImage(imageQuality: 90);
    for (final x in xs) {
      images.add(await widget.storage.copyToMedia(File(x.path), 'images'));
    }
    setState(() {});
  }

  Future<void> removeImage(int i) async {
    final p = images.removeAt(i);
    final f = File(p);
    if (await f.exists()) await f.delete();
    setState(() {});
  }

  Future<void> recordAudio() async {
    if (recording) {
      final path = await recorder.stop();
      setState(() => recording = false);
      if (path != null) {
        audioPath = await widget.storage.copyToMedia(File(path), 'audio');
        try {
          final temp = File(path);
          if (await temp.exists()) await temp.delete();
        } catch (_) {}
      }
      return;
    }
    if (!await recorder.hasPermission()) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('مجوز میکروفون لازم است.')),
        );
      return;
    }
    final dir = Directory('${widget.storage.mediaDir.path}/temp');
    if (!await dir.exists()) await dir.create(recursive: true);
    final path = '${dir.path}/${DateTime.now().microsecondsSinceEpoch}.m4a';
    await recorder.start(const RecordConfig(), path: path);
    setState(() => recording = true);
  }

  Future<void> playAudio() async {
    if (audioPath == null) return;
    if (playing) {
      await player.pause();
      setState(() => playing = false);
      return;
    }
    await player.play(DeviceFileSource(audioPath!));
    setState(() => playing = true);
  }

  Future<void> removeAudio() async {
    if (audioPath != null) {
      final f = File(audioPath!);
      if (await f.exists()) await f.delete();
    }
    audioPath = null;
    await player.stop();
    setState(() => playing = false);
  }

  Future<void> schedule() async {
    final now = DateTime.now();
    final base = reminder ?? now.add(const Duration(minutes: 10));
    final pickedDate = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 5),
      initialDate: DateTime(base.year, base.month, base.day),
      helpText: 'تاریخ یادآوری این یادداشت',
    );
    if (pickedDate == null || !mounted) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
      helpText: 'زمان یادآوری',
    );
    if (pickedTime == null || !mounted) return;
    final value = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
    if (!value.isAfter(now)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لطفاً زمان آینده‌ای برای یادآوری انتخاب کن.'),
        ),
      );
      return;
    }
    setState(() => reminder = value);
  }

  Future<void> addTag() async {
    final ctl = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('افزودن Tag'),
        content: TextField(
          controller: ctl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'مثلاً: خاطره'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('لغو'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctl.text.trim()),
            child: const Text('افزودن'),
          ),
        ],
      ),
    );
    ctl.dispose();
    if (value != null && value.isNotEmpty && !tags.contains(value)) {
      setState(() => tags.add(value));
    }
  }

  void applyMarkup(String open, String close) {
    final s = body.selection.start, e = body.selection.end;
    if (s < 0 || e < 0 || s == e) {
      body.text = '${body.text}$open$close';
      body.selection = TextSelection.collapsed(
        offset: body.text.length - open.length - close.length,
      );
      return;
    }
    final selected = body.text.substring(s, e);
    final next =
        '${body.text.substring(0, s)}$open$selected$close${body.text.substring(e)}';
    body.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(
        offset: e + open.length + close.length,
      ),
    );
  }

  NoteItem buildNote() {
    final now = DateTime.now();
    return NoteItem(
      id: widget.initial?.id ?? now.microsecondsSinceEpoch.toString(),
      title: title.text.trim(),
      body: body.text.trim(),
      createdAt: widget.initial?.createdAt ?? now,
      updatedAt: now,
      kind: kind,
      folder: folder,
      tags: tags,
      favorite: favorite,
      pinned: pinned,
      completed: checks.isNotEmpty && checks.every((e) => e.done),
      checkItems: checks,
      imagePaths: images,
      audioPath: audioPath,
      reminderAt: reminder,
      textSize: textSize,
      bold: bold,
      italic: italic,
      underline: underline,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = colorsFor(widget.theme);
    return Scaffold(
      backgroundColor: AppPalette.page,
      appBar: AppBar(
        title: Text(widget.initial == null ? 'یادداشت جدید' : 'ویرایش یادداشت'),
        actions: [
          IconButton(
            onPressed: () => setState(() => favorite = !favorite),
            icon: Icon(
              favorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: favorite ? Colors.pinkAccent : null,
            ),
          ),
          IconButton(
            onPressed: () => setState(() => pinned = !pinned),
            icon: Icon(
              pinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
              color: pinned ? Colors.amber : null,
            ),
          ),
          if (widget.initial != null && widget.onDelete != null)
            IconButton(
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (d) => AlertDialog(
                    title: const Text('حذف یادداشت'),
                    content: const Text('این یادداشت به سطل زباله منتقل شود؟'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(d, false),
                        child: const Text('لغو'),
                      ),
                      FilledButton.tonal(
                        onPressed: () => Navigator.pop(d, true),
                        child: const Text('حذف'),
                      ),
                    ],
                  ),
                );
                if (ok == true) {
                  await widget.onDelete!();
                  if (mounted) Navigator.pop(context);
                }
              },
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: Colors.redAccent,
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          _Reveal(
            child: _Glass(
              accent: c.primary,
              child: Column(
                children: [
                  TextField(
                    controller: title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'عنوان یادداشت',
                      border: InputBorder.none,
                      filled: false,
                    ),
                  ),
                  const Divider(),
                  Row(
                    children: [
                      Expanded(
                        child: _drop<NoteKind>(kind, {
                          for (final x in NoteKind.values) x: _kindLabel(x),
                        }, (x) => setState(() => kind = x)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _drop<NoteFolder>(folder, {
                          for (final x in NoteFolder.values) x: x.label,
                        }, (x) => setState(() => folder = x)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _tool(
                          Icons.format_bold_rounded,
                          bold,
                          () => setState(() => bold = !bold),
                          c.primary,
                        ),
                        _tool(
                          Icons.format_italic_rounded,
                          italic,
                          () => setState(() => italic = !italic),
                          c.primary,
                        ),
                        _tool(
                          Icons.format_underlined_rounded,
                          underline,
                          () => setState(() => underline = !underline),
                          c.primary,
                        ),
                        _tool(
                          Icons.code_rounded,
                          false,
                          () => applyMarkup('**', '**'),
                          c.primary,
                        ),
                        _tool(
                          Icons.format_italic_rounded,
                          false,
                          () => applyMarkup('_', '_'),
                          c.primary,
                        ),
                        _tool(
                          Icons.format_underlined_rounded,
                          false,
                          () => applyMarkup('__', '__'),
                          c.primary,
                        ),
                        IconButton(
                          onPressed: () => setState(
                            () =>
                                textSize = (textSize >= 23 ? 15 : textSize + 2),
                          ),
                          icon: const Icon(Icons.text_increase_rounded),
                        ),
                        IconButton(
                          onPressed: () => setState(
                            () =>
                                textSize = (textSize <= 15 ? 23 : textSize - 2),
                          ),
                          icon: const Icon(Icons.text_decrease_rounded),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: body,
                    maxLines: 10,
                    style: TextStyle(
                      fontSize: textSize,
                      fontWeight: bold ? FontWeight.w800 : null,
                      fontStyle: italic ? FontStyle.italic : FontStyle.normal,
                      decoration: underline ? TextDecoration.underline : null,
                      height: 1.55,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'حرفت را اینجا بنویس...',
                      fillColor: Colors.transparent,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      ...tags.map(
                        (t) => InputChip(
                          label: Text('#$t'),
                          onDeleted: () => setState(() => tags.remove(t)),
                        ),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.add_rounded, size: 16),
                        label: const Text('Tag'),
                        onPressed: addTag,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _EditorSection(
            title: 'نوع و گزینه‌ها',
            color: c.primary,
            children: [
              if (kind == NoteKind.checklist) _checkEditor(c.primary),
              if (kind == NoteKind.memory) _memoryEditor(c.primary),
              _Glass(
                accent: c.secondary,
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: reminder != null,
                      onChanged: (v) async {
                        if (v)
                          await schedule();
                        else {
                          setState(() => reminder = null);
                        }
                      },
                      secondary: Icon(
                        Icons.notifications_active_rounded,
                        color: c.secondary,
                      ),
                      title: const Text('یادآوری این یادداشت'),
                      subtitle: Text(
                        reminder == null
                            ? 'برای این یادداشت زمان یادآوری انتخاب کن'
                            : DateFormat('yyyy/MM/dd HH:mm').format(reminder!),
                      ),
                    ),
                    if (audioPath != null || recording) _audioEditor(c.primary),
                    if (kind != NoteKind.memory) _attachmentRow(c.primary),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, buildNote()),
            icon: const Icon(Icons.check_circle_rounded),
            label: const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text(
                'ذخیره یادداشت',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (widget.initial != null)
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.undo_rounded),
              label: const Text('لغو تغییرات'),
            ),
        ],
      ),
    );
  }

  Widget _drop<T>(T value, Map<T, String> items, ValueChanged<T> onChanged) =>
      DropdownButtonFormField<T>(
        initialValue: value,
        isExpanded: true,
        decoration: const InputDecoration(
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        ),
        items: items.entries
            .map(
              (e) => DropdownMenuItem(
                value: e.key,
                child: Text(e.value, overflow: TextOverflow.ellipsis),
              ),
            )
            .toList(),
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      );
  Widget _tool(IconData icon, bool active, VoidCallback onTap, Color c) =>
      Padding(
        padding: const EdgeInsets.only(right: 3),
        child: IconButton(
          onPressed: onTap,
          style: IconButton.styleFrom(
            backgroundColor: active
                ? c.withValues(alpha: .16)
                : Colors.white.withValues(alpha: .04),
          ),
          icon: Icon(icon, color: active ? c : null),
        ),
      );
  Widget _checkEditor(Color c) {
    return Column(
      children: [
        ...List.generate(
          checks.length,
          (i) => Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Row(
              children: [
                Checkbox(
                  value: checks[i].done,
                  onChanged: (v) => setState(() => checks[i].done = v ?? false),
                ),
                Expanded(
                  child: TextFormField(
                    initialValue: checks[i].text,
                    onChanged: (v) => checks[i].text = v,
                    decoration: InputDecoration(hintText: 'مورد ${i + 1}'),
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => checks.removeAt(i)),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() => checks.add(CheckItem(text: ''))),
            icon: const Icon(Icons.add_rounded),
            label: const Text('افزودن مورد'),
          ),
        ),
      ],
    );
  }

  Widget _memoryEditor(Color c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        Row(
          children: [
            const Expanded(
              child: Text(
                'عکس‌های خاطره',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: pickImages,
              icon: const Icon(Icons.add_photo_alternate_rounded),
              label: const Text('افزودن'),
            ),
          ],
        ),
        if (images.isNotEmpty)
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.file(
                      File(images[i]),
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 3,
                    right: 3,
                    child: Material(
                      color: Colors.black54,
                      shape: const CircleBorder(),
                      child: IconButton(
                        onPressed: () => removeImage(i),
                        padding: const EdgeInsets.all(2),
                        constraints: const BoxConstraints(),
                        icon: const Icon(Icons.close_rounded, size: 18),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (images.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Text(
              'بدون عکس هم می‌توانی خاطره بسازی.',
              style: TextStyle(color: Colors.white.withValues(alpha: .48)),
            ),
          ),
      ],
    );
  }

  Widget _attachmentRow(Color c) => Row(
    children: [
      Expanded(
        child: FilledButton.tonalIcon(
          onPressed: recordAudio,
          icon: Icon(recording ? Icons.stop_circle_rounded : Icons.mic_rounded),
          label: Text(recording ? 'توقف ضبط' : 'ضبط صدا'),
        ),
      ),
      const SizedBox(width: 8),
      if (audioPath != null)
        IconButton(
          onPressed: removeAudio,
          icon: const Icon(
            Icons.delete_outline_rounded,
            color: Colors.redAccent,
          ),
          tooltip: 'حذف صدا',
        ),
    ],
  );
  Widget _audioEditor(Color c) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: c.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.graphic_eq_rounded, color: c),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'یادداشت صوتی',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                onPressed: playAudio,
                icon: Icon(
                  playing
                      ? Icons.pause_circle_filled_rounded
                      : Icons.play_circle_fill_rounded,
                  color: c,
                  size: 32,
                ),
              ),
              IconButton(
                onPressed: removeAudio,
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.redAccent,
                ),
              ),
            ],
          ),
          Slider(
            value: audioDuration.inMilliseconds == 0
                ? 0
                : (audioPosition.inMilliseconds.toDouble().clamp(
                    0,
                    audioDuration.inMilliseconds.toDouble(),
                  )).toDouble(),
            max: audioDuration.inMilliseconds == 0
                ? 1
                : audioDuration.inMilliseconds.toDouble(),
            onChanged: (v) async {
              await player.seek(Duration(milliseconds: v.round()));
            },
          ),
        ],
      ),
    ),
  );
  String _kindLabel(NoteKind x) => switch (x) {
    NoteKind.note => 'یادداشت',
    NoteKind.checklist => 'چک‌لیست',
    NoteKind.letter => 'نامه',
    NoteKind.memory => 'خاطره',
  };
}

class _EditorSection extends StatelessWidget {
  const _EditorSection({
    required this.title,
    required this.color,
    required this.children,
  });
  final String title;
  final Color color;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 16,
        ),
      ),
      const SizedBox(height: 8),
      ...children,
    ],
  );
}

class NoteReader extends StatelessWidget {
  const NoteReader({
    super.key,
    required this.note,
    required this.color,
    this.onDelete,
  });
  final NoteItem note;
  final Color color;
  final VoidCallback? onDelete;

  Future<void> _share() async {
    final buffer = StringBuffer();
    buffer.writeln(note.title.isEmpty ? 'Big Sister Notes ❤️' : note.title);
    buffer.writeln();
    buffer.writeln(note.body);
    if (note.tags.isNotEmpty)
      buffer.writeln('\n${note.tags.map((e) => '#$e').join(' ')}');
    await SharePlus.instance.share(
      ShareParams(text: buffer.toString(), subject: note.title),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    note.title.isEmpty ? 'بدون عنوان' : note.title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _share,
                  icon: const Icon(Icons.share_rounded),
                ),
                if (onDelete != null)
                  IconButton(
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (d) => AlertDialog(
                          title: const Text('حذف یادداشت'),
                          content: const Text(
                            'این مورد به سطل زباله منتقل شود؟',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(d, false),
                              child: const Text('لغو'),
                            ),
                            FilledButton.tonal(
                              onPressed: () => Navigator.pop(d, true),
                              child: const Text('حذف'),
                            ),
                          ],
                        ),
                      );
                      if (ok == true && context.mounted) {
                        onDelete!();
                        Navigator.pop(context);
                      }
                    },
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.redAccent,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      note.body,
                      style: TextStyle(
                        fontSize: note.textSize,
                        height: 1.6,
                        fontWeight: note.bold ? FontWeight.w800 : null,
                        fontStyle: note.italic
                            ? FontStyle.italic
                            : FontStyle.normal,
                        decoration: note.underline
                            ? TextDecoration.underline
                            : null,
                      ),
                    ),
                    if (note.checkItems.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      ...note.checkItems.map(
                        (e) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            e.done
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked_rounded,
                            color: e.done ? color : Colors.white38,
                          ),
                          title: Text(
                            e.text,
                            style: TextStyle(
                              decoration: e.done
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (note.tags.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 6,
                        children: note.tags
                            .map((t) => Chip(label: Text('#$t')))
                            .toList(),
                      ),
                    ],
                    if (note.imagePaths.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      ...note.imagePaths.map(
                        (p) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Image.file(File(p), fit: BoxFit.cover),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LockScreen extends StatefulWidget {
  const LockScreen({super.key, required this.storage, required this.onUnlock});

  final StorageService storage;
  final VoidCallback onUnlock;

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final ctl = TextEditingController();
  String error = '';
  bool bioBusy = false;

  bool get hasPin => widget.storage.loadPin() != null;
  bool get hasBio => widget.storage.loadBiometric();

  @override
  void dispose() {
    ctl.dispose();
    super.dispose();
  }

  Future<void> unlockPin() async {
    final pin = widget.storage.loadPin();
    if (pin != null && ctl.text == pin) {
      widget.onUnlock();
    } else if (mounted) {
      setState(() => error = 'PIN اشتباه است.');
    }
  }

  Future<void> unlockBio() async {
    setState(() => bioBusy = true);
    try {
      final ok = await LocalAuthentication().authenticate(
        localizedReason: 'برای ورود به دفتر خواهر بزرگم احراز هویت کن',
        biometricOnly: true,
      );
      if (ok) widget.onUnlock();
    } catch (_) {
      if (mounted) setState(() => error = 'احراز هویت انجام نشد.');
    } finally {
      if (mounted) setState(() => bioBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = colorsFor(AppThemeChoice.turquoise);
    return Scaffold(
      backgroundColor: AppPalette.page,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: _Glass(
            accent: c.primary,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _BreathingLogo(color: Color(0xFF19E0CE)),
                const SizedBox(height: 18),
                const Text(
                  'Big Sister Notes',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 7),
                const Text(
                  'دفتر خصوصی خواهر بزرگم',
                  style: TextStyle(color: Colors.white54),
                ),
                if (hasPin) ...[
                  const SizedBox(height: 18),
                  TextField(
                    controller: ctl,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      hintText: 'PIN',
                      counterText: '',
                    ),
                    onSubmitted: (_) => unlockPin(),
                  ),
                  if (error.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        error,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: unlockPin,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: Text('ورود'),
                      ),
                    ),
                  ),
                ],
                if (hasBio) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: bioBusy ? null : unlockBio,
                    icon: const Icon(Icons.fingerprint_rounded),
                    label: Text(
                      bioBusy ? 'در حال بررسی...' : 'ورود با بیومتریک',
                    ),
                  ),
                ],
                if (!hasPin && !hasBio) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'قفل فعال است اما روش ورود تنظیم نشده است.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Glass extends StatelessWidget {
  const _Glass({this.child, this.accent, this.onTap});
  final Widget? child;
  final Color? accent;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final a = accent ?? colorsFor(AppThemeChoice.turquoise).primary;
    final content = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.white.withValues(alpha: .055)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .24),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: a.withValues(alpha: .035),
            blurRadius: 26,
            spreadRadius: 1,
          ),
        ],
      ),
      child: child,
    );
    return onTap == null
        ? content
        : Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(25),
              child: content,
            ),
          );
  }
}
