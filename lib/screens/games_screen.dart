import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/app_models.dart' show AppThemeChoice;
import '../cloud/cloud_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';

class GamesTab extends StatelessWidget {
  const GamesTab({super.key, required this.theme, required this.cloud});

  final AppThemeChoice theme;
  final CloudService cloud;

  @override
  Widget build(BuildContext context) => _GamesHome(theme: theme, cloud: cloud);
}

class _GameDefinition {
  const _GameDefinition({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.accent,
    required this.tag,
  });

  final String id;
  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
  final Color accent;
  final String tag;
}

const _games = <_GameDefinition>[
  _GameDefinition(
    id: 'tic_tac_toe',
    title: 'دوز',
    subtitle: 'سه‌تایی‌ها را ردیف کن',
    description: 'یک رقابت سریع و هوشمندانه؛ سه علامت را قبل از نفر مقابل کنار هم بچین.',
    icon: Icons.grid_3x3_rounded,
    accent: Color(0xFF5AD6FF),
    tag: 'استراتژی سریع',
  ),
  _GameDefinition(
    id: 'connect_four',
    title: 'چهاردرخط',
    subtitle: 'چهار مهره پشت سر هم',
    description: 'با دقت ستون مناسب را انتخاب کن و مسیر حرکت نفر مقابل را ببند.',
    icon: Icons.circle_rounded,
    accent: Color(0xFFFFB45C),
    tag: 'فکری و رقابتی',
  ),
  _GameDefinition(
    id: 'riddles',
    title: 'نبرد چیستان',
    subtitle: 'فکر کن، جواب بده، امتیاز بگیر',
    description: 'چیستان‌ها به نوبت نمایش داده می‌شوند؛ جواب درست یک امتیاز دارد.',
    icon: Icons.psychology_alt_rounded,
    accent: Color(0xFFB69BFF),
    tag: 'هوش و دانستنی',
  ),
  _GameDefinition(
    id: 'rock_paper_scissors',
    title: 'سنگ، کاغذ، قیچی',
    subtitle: 'انتخاب مخفی و رقابت هم‌زمان',
    description: 'هر دو نفر هم‌زمان انتخاب می‌کنند؛ اولین نفر با سه برد، قهرمان مسابقه است.',
    icon: Icons.pan_tool_rounded,
    accent: Color(0xFFFF8FA3),
    tag: 'سرعت و شانس',
  ),
  _GameDefinition(
    id: 'memory_match',
    title: 'کارت‌های حافظه',
    subtitle: 'جفت‌های مشابه را پیدا کن',
    description: 'کارت‌ها را به خاطر بسپار، جفت‌ها را پیدا کن و با امتیاز بیشتر برنده شو.',
    icon: Icons.grid_view_rounded,
    accent: Color(0xFF70E0B3),
    tag: 'تقویت حافظه',
  ),
  _GameDefinition(
    id: 'hangman',
    title: 'حدس کلمه',
    subtitle: 'حروف پنهان را کشف کن',
    description: 'حرف‌ها را به نوبت انتخاب کنید و پیش از تمام شدن فرصت‌ها کلمه را پیدا کنید.',
    icon: Icons.spellcheck_rounded,
    accent: Color(0xFFFFD166),
    tag: 'واژه و تمرکز',
  ),
  _GameDefinition(
    id: 'math_duel',
    title: 'نبرد ریاضی',
    subtitle: 'محاسبه کن و امتیاز بگیر',
    description: 'مسئله‌های کوتاه جمع، تفریق، ضرب و تقسیم را به نوبت حل کنید.',
    icon: Icons.calculate_rounded,
    accent: Color(0xFF8CB8FF),
    tag: 'ذهن سریع',
  ),
  _GameDefinition(
    id: 'word_chain',
    title: 'زنجیره کلمات',
    subtitle: 'با حرف آخر ادامه بده',
    description: 'هر واژه باید با آخرین حرف واژه قبلی شروع شود؛ واژه تکراری پذیرفته نیست.',
    icon: Icons.text_fields_rounded,
    accent: Color(0xFFD6A6FF),
    tag: 'واژه‌سازی',
  ),
  _GameDefinition(
    id: 'number_guess',
    title: 'راز عدد',
    subtitle: 'عدد مخفی را پیدا کن',
    description: 'یک عدد بین ۱ تا ۵۰ را با راهنمایی بیشتر یا کمتر در حداکثر هفت تلاش پیدا کن.',
    icon: Icons.dialpad_rounded,
    accent: Color(0xFFFFB86B),
    tag: 'استدلال منطقی',
  ),
  _GameDefinition(
    id: 'mines_duel',
    title: 'مین‌یاب',
    subtitle: 'خانه امن را پیدا کن',
    description: 'خانه‌ها را به نوبت باز کنید؛ مین پنهان می‌تواند نتیجه مسابقه را عوض کند.',
    icon: Icons.grid_on_rounded,
    accent: Color(0xFFFF7D7D),
    tag: 'ریسک و دقت',
  ),
  _GameDefinition(
    id: 'name_family',
    title: 'اسم فامیل',
    subtitle: 'با یک حرف، هفت دسته را کامل کن',
    description: 'اسم، فامیل، شهر، کشور، میوه، غذا و اشیا؛ در دونفره امتیازها دستی ثبت می‌شوند.',
    icon: Icons.text_fields_rounded,
    accent: Color(0xFF7DE0E8),
    tag: 'سرعت و واژه',
  ),
];

class _GamesHome extends StatefulWidget {
  const _GamesHome({required this.theme, required this.cloud});
  final AppThemeChoice theme;
  final CloudService cloud;

  @override
  State<_GamesHome> createState() => _GamesHomeState();
}

class _GamesHomeState extends State<_GamesHome> {
  StreamSubscription<Map<String, dynamic>>? _gameSubscription;
  StreamSubscription<bool>? _connectionSubscription;
  Map<String, dynamic>? _activeState;
  int _revision = 0;
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _gameSubscription = widget.cloud.gameUpdates.listen(_receiveUpdate);
    _connectionSubscription = widget.cloud.connectionChanges.listen((_) {
      if (mounted) setState(() {});
      if (widget.cloud.online && _activeState == null) unawaited(_loadState());
    });
    unawaited(_loadState());
  }

  @override
  void dispose() {
    _gameSubscription?.cancel();
    _connectionSubscription?.cancel();
    super.dispose();
  }

  void _receiveUpdate(Map<String, dynamic> data) {
    final revision = _asInt(data['revision']);
    if (revision < _revision) return;
    final rawState = data['state'];
    setState(() {
      _revision = revision;
      _activeState = rawState is Map ? Map<String, dynamic>.from(rawState) : null;
      _loading = false;
      _loadError = null;
    });
  }

  Future<void> _loadState() async {
    if (!widget.cloud.configured) {
      if (mounted) setState(() { _loading = false; _loadError = null; });
      return;
    }
    if (mounted) setState(() { _loading = true; _loadError = null; });
    try {
      final result = await widget.cloud.fetchGameState();
      if (!mounted) return;
      setState(() {
        _revision = _asInt(result['revision']);
        final value = result['state'];
        _activeState = value is Map ? Map<String, dynamic>.from(value) : null;
        _loading = false;
        _loadError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = _friendlyError(error);
      });
    }
  }

  Future<void> _openGame(_GameDefinition game) async {
    final mode = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF101A29),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 42, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 18),
            Text(game.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 7),
            const Text('روش بازی را انتخاب کن', style: TextStyle(color: Colors.white60, fontSize: 12)),
            const SizedBox(height: 18),
            SizedBox(width: double.infinity, child: FilledButton.icon(
              onPressed: () => Navigator.pop(sheetContext, 'solo'),
              icon: const Icon(Icons.person_rounded),
              label: const Text('تک‌نفره · آفلاین'),
              style: FilledButton.styleFrom(backgroundColor: game.accent, foregroundColor: const Color(0xFF061018), padding: const EdgeInsets.symmetric(vertical: 14)),
            )),
            const SizedBox(height: 10),
            SizedBox(width: double.infinity, child: OutlinedButton.icon(
              onPressed: () => Navigator.pop(sheetContext, 'duo'),
              icon: const Icon(Icons.people_alt_rounded),
              label: const Text('دونفره زنده با خواهرت'),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: BorderSide(color: game.accent.withValues(alpha: .55)), padding: const EdgeInsets.symmetric(vertical: 14)),
            )),
          ]),
        ),
      ),
    );
    if (!mounted || mode == null) return;
    if (mode == 'solo') {
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => _SoloGameScreen(game: game, theme: widget.theme),
      ));
      return;
    }
    if (!widget.cloud.configured) {
      _showMessage('برای بازی دونفره زنده، ابتدا هر دو دستگاه را به اتاق خصوصی وصل کنید.');
      return;
    }
    if (_loading) await _loadState();
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => _GameRoomScreen(
        game: game,
        cloud: widget.cloud,
        theme: widget.theme,
        initialState: _activeState,
        initialRevision: _revision,
      ),
    ));
    await _loadState();
  }

  void _showMessage(String value) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = colorsFor(widget.theme);
    final activeGame = _games.where((g) => g.id == _activeState?['gameId']).firstOrNull;
    final isActive = _activeState?['status'] == 'playing';
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadState,
        color: colors.primary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 132),
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: LinearGradient(colors: [colors.primary, colors.secondary]),
                    boxShadow: [BoxShadow(color: colors.glow.withValues(alpha: .22), blurRadius: 22)],
                  ),
                  child: const Icon(Icons.sports_esports_rounded, color: Color(0xFF071018), size: 29),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('وقت بازیه! 🎮', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      Text('بازی فکری؛ تک‌نفره یا در رقابت زنده با ${widget.cloud.otherDisplayName}', style: TextStyle(color: Colors.white.withValues(alpha: .55), fontSize: 12)),
                    ],
                  ),
                ),
                _ConnectionPill(online: widget.cloud.online),
              ],
            ),
            const SizedBox(height: 20),
            GlassCard(
              accent: colors.primary,
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('دو روش بازی', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 6),
                        Text(
                          widget.cloud.configured ? 'تک‌نفره آفلاین یا دونفره زنده؛ انتخاب با توست.' : 'تک‌نفره آفلاین همیشه در دسترس است؛ برای دونفره زنده اتصال دو دستگاه را کامل کن.',
                          style: TextStyle(color: Colors.white.withValues(alpha: .58), fontSize: 12, height: 1.6),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(Icons.verified_user_rounded, color: colors.primary, size: 28),
                ],
              ),
            ),
            if (isActive && activeGame != null) ...[
              const SizedBox(height: 18),
              _ActiveGameCard(
                game: activeGame,
                state: _activeState!,
                cloud: widget.cloud,
                onTap: () => _openGame(activeGame),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                const Expanded(child: Text('۱۱ بازی · تک‌نفره یا دونفره', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
                Text('${_games.length} بازی', style: TextStyle(color: Colors.white.withValues(alpha: .42), fontSize: 11)),
              ],
            ),
            const SizedBox(height: 12),
            for (final game in _games) ...[
              _GameCard(game: game, onTap: () => _openGame(game)),
              const SizedBox(height: 12),
            ],
            if (_loading) ...[
              const SizedBox(height: 8),
              const Center(child: CircularProgressIndicator()),
            ],
            if (_loadError != null && !_loading) ...[
              const SizedBox(height: 8),
              GlassCard(
                accent: Colors.orangeAccent,
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: Colors.orangeAccent),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_loadError!, style: const TextStyle(fontSize: 12, height: 1.6))),
                    IconButton(onPressed: _loadState, icon: const Icon(Icons.refresh_rounded)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            Center(child: Text('همه بازی‌ها تک‌نفره آفلاین و دونفره زنده دارند.', style: TextStyle(color: Colors.white.withValues(alpha: .36), fontSize: 10), textAlign: TextAlign.center)),
          ],
        ),
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  const _GameCard({required this.game, required this.onTap});
  final _GameDefinition game;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GlassCard(
        accent: game.accent,
        onTap: onTap,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(color: game.accent.withValues(alpha: .12), borderRadius: BorderRadius.circular(19)),
              child: Icon(game.icon, color: game.accent, size: 31),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [Expanded(child: Text(game.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900))), _MiniTag(text: game.tag, color: game.accent)]),
                  const SizedBox(height: 5),
                  Text(game.subtitle, style: TextStyle(color: Colors.white.withValues(alpha: .7), fontSize: 12, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(game.description, style: TextStyle(color: Colors.white.withValues(alpha: .43), fontSize: 10, height: 1.5)),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_left_rounded, color: game.accent, size: 24),
          ],
        ),
      );
}

class _ActiveGameCard extends StatelessWidget {
  const _ActiveGameCard({required this.game, required this.state, required this.cloud, required this.onTap});
  final _GameDefinition game;
  final Map<String, dynamic> state;
  final CloudService cloud;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final myRole = cloud.role ?? 'me';
    final turn = state['turn']?.toString() ?? '';
    final isMyTurn = turn == myRole;
    final scores = _readScores(state['scores']);
    final turnLabel = game.id == 'rock_paper_scissors'
        ? 'انتخاب هم‌زمان'
        : (isMyTurn ? 'نوبت تو' : 'نوبت ${cloud.otherDisplayName}');
    return GlassCard(
      accent: game.accent,
      onTap: onTap,
      padding: const EdgeInsets.all(17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(Icons.bolt_rounded, color: game.accent), const SizedBox(width: 7), const Text('بازی در جریان', style: TextStyle(fontWeight: FontWeight.w900)), const Spacer(), _MiniTag(text: turnLabel, color: isMyTurn ? game.accent : Colors.pinkAccent)]),
          const SizedBox(height: 12),
          Text(game.title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
          const SizedBox(height: 9),
          Row(children: [
            _TinyScore(label: 'تو', score: scores[myRole] ?? 0, color: game.accent),
            const SizedBox(width: 8),
            _TinyScore(label: cloud.otherDisplayName, score: scores[myRole == 'me' ? 'sister' : 'me'] ?? 0, color: Colors.pinkAccent),
            const Spacer(),
            Text('ادامه بازی', style: TextStyle(color: game.accent, fontWeight: FontWeight.w800, fontSize: 12)),
            Icon(Icons.arrow_back_rounded, color: game.accent, size: 17),
          ]),
        ],
      ),
    );
  }
}

class _GameRoomScreen extends StatefulWidget {
  const _GameRoomScreen({
    required this.game,
    required this.cloud,
    required this.theme,
    required this.initialState,
    required this.initialRevision,
  });
  final _GameDefinition game;
  final CloudService cloud;
  final AppThemeChoice theme;
  final Map<String, dynamic>? initialState;
  final int initialRevision;

  @override
  State<_GameRoomScreen> createState() => _GameRoomScreenState();
}

class _GameRoomScreenState extends State<_GameRoomScreen> {
  StreamSubscription<Map<String, dynamic>>? _gameSubscription;
  StreamSubscription<bool>? _connectionSubscription;
  Map<String, dynamic>? _state;
  int _revision = 0;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  final TextEditingController _answerController = TextEditingController();
  final Map<String, String> _nameFamilyDraft = {};
  final Map<String, Map<String, int>> _nameFamilyManualDraft = {};

  String get _myRole => widget.cloud.role ?? 'me';
  String get _otherRole => _myRole == 'me' ? 'sister' : 'me';
  ThemeColors get _colors => colorsFor(widget.theme);

  @override
  void initState() {
    super.initState();
    _revision = widget.initialRevision;
    _state = widget.initialState == null ? null : Map<String, dynamic>.from(widget.initialState!);
    _gameSubscription = widget.cloud.gameUpdates.listen(_receiveUpdate);
    _connectionSubscription = widget.cloud.connectionChanges.listen((_) {
      if (mounted) setState(() {});
    });
    unawaited(_prepareGame());
  }

  @override
  void dispose() {
    _gameSubscription?.cancel();
    _connectionSubscription?.cancel();
    _answerController.dispose();
    super.dispose();
  }

  void _receiveUpdate(Map<String, dynamic> data) {
    final revision = _asInt(data['revision']);
    if (revision < _revision) return;
    final rawState = data['state'];
    if (rawState is! Map || rawState['gameId'] != widget.game.id) return;
    if (!mounted) return;
    setState(() {
      _revision = revision;
      _state = Map<String, dynamic>.from(rawState);
      _error = null;
    });
  }

  Future<void> _prepareGame() async {
    if (!widget.cloud.configured) {
      setState(() { _loading = false; _error = 'حساب به اتاق خصوصی متصل نیست.'; });
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final latest = await widget.cloud.fetchGameState();
      if (!mounted) return;
      _revision = _asInt(latest['revision']);
      final raw = latest['state'];
      _state = raw is Map ? Map<String, dynamic>.from(raw) : null;
      if (_state == null || _state!['gameId'] != widget.game.id || _state!['status'] == 'finished') {
        if (_state != null && _state!['status'] == 'playing' && _state!['gameId'] != widget.game.id) {
          final approved = await _confirmReplace(_state!['gameId']?.toString());
          if (!approved) { if (mounted) Navigator.pop(context); return; }
        }
        final sameGameRematch = _state != null && _state!['gameId'] == widget.game.id && _state!['status'] == 'finished';
        await _startNewGame(previous: sameGameRematch ? _state : null);
      }
      if (mounted) setState(() => _loading = false);
    } catch (error) {
      if (!mounted) return;
      setState(() { _loading = false; _error = _friendlyError(error); });
    }
  }

  Future<bool> _confirmReplace(String? oldGameId) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('شروع یک بازی تازه؟'),
            content: Text('بازی «${_gameTitle(oldGameId)}» هنوز تمام نشده است. با شروع این بازی، آن مسابقه بسته می‌شود.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('لغو')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('شروع')),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _startNewGame({Map<String, dynamic>? previous}) async {
    final keepScore = previous != null && previous['gameId'] == widget.game.id;
    var oldScores = <String, int>{'me': 0, 'sister': 0};
    if (keepScore && previous != null) {
      oldScores = _readScores(previous['scores']);
    }
    var oldStarter = _myRole;
    if (keepScore && previous != null) {
      final previousStarter = previous['starter'];
      oldStarter = previousStarter?.toString() ?? _myRole;
    }
    var starter = _myRole;
    if (keepScore) {
      starter = oldStarter == 'me' ? 'sister' : 'me';
    }
    final now = DateTime.now().toUtc().toIso8601String();
    final next = <String, dynamic>{
      'gameId': widget.game.id,
      'matchId': '${DateTime.now().microsecondsSinceEpoch}-$_myRole',
      'status': 'playing',
      'turn': starter,
      'starter': starter,
      'scores': oldScores,
      'createdAt': now,
      'updatedAt': now,
    };
    if (widget.game.id == 'tic_tac_toe') next['board'] = List<String?>.filled(9, null);
    if (widget.game.id == 'connect_four') next['board'] = List<String?>.filled(42, null);
    if (widget.game.id == 'riddles') {
      next['riddleIndex'] = 0;
      next['lastResult'] = null;
    }
    if (widget.game.id == 'rock_paper_scissors') {
      next['round'] = 1;
      next['choices'] = <String, dynamic>{'me': null, 'sister': null};
      next['lastRound'] = null;
    }
    if (widget.game.id == 'memory_match') {
      final symbols = List<String>.from(_memorySymbols)..addAll(_memorySymbols);
      symbols.shuffle(math.Random());
      next['deck'] = symbols;
      next['revealed'] = <int>[];
      next['matched'] = <int>[];
      next['pendingMismatch'] = false;
      next['pairsFound'] = 0;
    }
    if (widget.game.id == 'hangman') {
      final words = List<String>.from(_hangmanWords)..shuffle(math.Random());
      next['word'] = _normalizeWord(words.first);
      next['guessed'] = <String>[];
      next['wrongCount'] = 0;
      next['lastGuess'] = null;
    }
    if (widget.game.id == 'math_duel') {
      final order = List<int>.generate(_mathQuestions.length, (index) => index)..shuffle(math.Random());
      next['questionOrder'] = order.take(10).toList();
      next['questionIndex'] = 0;
      next['lastAnswer'] = null;
    }
    if (widget.game.id == 'word_chain') {
      final seeds = List<String>.from(_wordSeeds)..shuffle(math.Random());
      next['words'] = <String>[seeds.first];
      next['wordAuthors'] = <String>['system'];
      next['wordMoves'] = 0;
    }
    if (widget.game.id == 'number_guess') {
      next['setter'] = starter;
      next['secretNumber'] = math.Random.secure().nextInt(50) + 1;
      next['attempts'] = 0;
      next['lastGuess'] = null;
      next['lastHint'] = null;
      next['turn'] = starter == 'me' ? 'sister' : 'me';
    }
    if (widget.game.id == 'mines_duel') {
      final positions = List<int>.generate(25, (index) => index)..shuffle(math.Random());
      next['mines'] = positions.take(5).toList();
      next['revealed'] = <int>[];
      next['exploded'] = null;
    }
    if (widget.game.id == 'name_family') {
      next['round'] = 1;
      next['letter'] = _nameFamilyLetters[math.Random().nextInt(_nameFamilyLetters.length)];
      next['categories'] = _nameFamilyCategories;
      next['answers'] = <String, dynamic>{'me': <String, dynamic>{}, 'sister': <String, dynamic>{}};
      next['submitted'] = <String, dynamic>{'me': false, 'sister': false};
      next['manualCategoryScores'] = <String, dynamic>{};
      next['roundScored'] = false;
    }
    _nameFamilyDraft.clear();
    _nameFamilyManualDraft.clear();
    await _saveState(next, showConflict: false);
  }

  Future<bool> _saveState(Map<String, dynamic> next, {bool showConflict = true}) async {
    if (_saving) return false;
    setState(() { _saving = true; _error = null; });
    try {
      next['updatedAt'] = DateTime.now().toUtc().toIso8601String();
      final result = await widget.cloud.saveGameState(state: next, expectedRevision: _revision);
      if (result['conflict'] == true) {
        final raw = result['state'];
        if (mounted) {
          setState(() {
            _revision = _asInt(result['revision']);
            _state = raw is Map ? Map<String, dynamic>.from(raw) : null;
          });
        }
        if (showConflict && mounted) _showMessage('بازی روی گوشی دیگر تغییر کرده؛ وضعیت تازه جایگزین شد. دوباره امتحان کن.');
        return false;
      }
      final raw = result['state'];
      if (mounted) {
        setState(() {
          _revision = _asInt(result['revision']);
          _state = raw is Map ? Map<String, dynamic>.from(raw) : Map<String, dynamic>.from(next);
        });
      }
      return true;
    } catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error));
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _tapTicCell(int index) async {
    final state = _state;
    if (state == null || !_canMove) return;
    final board = (state['board'] as List? ?? const []).map((e) => e?.toString()).toList();
    if (index < 0 || index >= board.length || board[index] != null) return;
    board[index] = _myRole;
    final next = Map<String, dynamic>.from(state)..['board'] = board;
    final winner = _findWinner(board, const [
      [0, 1, 2], [3, 4, 5], [6, 7, 8],
      [0, 3, 6], [1, 4, 7], [2, 5, 8],
      [0, 4, 8], [2, 4, 6],
    ]);
    if (winner != null) {
      next['status'] = 'finished';
      next['winner'] = winner;
      _addScore(next, winner);
    } else if (board.every((cell) => cell != null)) {
      next['status'] = 'finished';
      next['winner'] = 'draw';
    } else {
      next['turn'] = _otherRole;
    }
    await _saveState(next);
  }

  Future<void> _dropConnectFour(int column) async {
    final state = _state;
    if (state == null || !_canMove) return;
    final board = (state['board'] as List? ?? const []).map((e) => e?.toString()).toList();
    if (board.length != 42) return;
    var placedAt = -1;
    for (var row = 5; row >= 0; row--) {
      final index = row * 7 + column;
      if (board[index] == null) { placedAt = index; break; }
    }
    if (placedAt < 0) return;
    board[placedAt] = _myRole;
    final next = Map<String, dynamic>.from(state)..['board'] = board;
    final winner = _findConnectFourWinner(board);
    if (winner != null) {
      next['status'] = 'finished';
      next['winner'] = winner;
      _addScore(next, winner);
    } else if (board.every((cell) => cell != null)) {
      next['status'] = 'finished';
      next['winner'] = 'draw';
    } else {
      next['turn'] = _otherRole;
    }
    await _saveState(next);
  }

  String? _findConnectFourWinner(List<String?> board) {
    for (var row = 0; row < 6; row++) {
      for (var col = 0; col < 7; col++) {
        final role = board[row * 7 + col];
        if (role == null) continue;
        for (final direction in const [(0, 1), (1, 0), (1, 1), (1, -1)]) {
          var count = 1;
          for (var step = 1; step < 4; step++) {
            final r = row + direction.$1 * step;
            final c = col + direction.$2 * step;
            if (r < 0 || r >= 6 || c < 0 || c >= 7 || board[r * 7 + c] != role) break;
            count++;
          }
          if (count >= 4) return role;
        }
      }
    }
    return null;
  }

  Future<void> _submitRiddle() async {
    final state = _state;
    if (state == null || !_canMove) return;
    final answer = _normalizeAnswer(_answerController.text);
    if (answer.isEmpty) return;
    final index = _asInt(state['riddleIndex']);
    if (index >= _riddles.length) return;
    final riddle = _riddles[index];
    final correct = riddle.answers.map(_normalizeAnswer).contains(answer);
    final next = Map<String, dynamic>.from(state);
    final scores = _readScores(state['scores']);
    if (correct) scores[_myRole] = (scores[_myRole] ?? 0) + 1;
    next['scores'] = scores;
    next['riddleIndex'] = index + 1;
    next['lastResult'] = {
      'by': _myRole,
      'correct': correct,
      'answer': riddle.answers.first,
      'guess': _answerController.text.trim(),
    };
    if (index + 1 >= _riddles.length) {
      next['status'] = 'finished';
      final meScore = scores['me'] ?? 0;
      final sisterScore = scores['sister'] ?? 0;
      next['winner'] = meScore == sisterScore ? 'draw' : (meScore > sisterScore ? 'me' : 'sister');
    } else {
      next['turn'] = _otherRole;
    }
    final saved = await _saveState(next);
    if (saved && mounted) _answerController.clear();
  }

  Future<void> _chooseRps(String choice) async {
    final state = _state;
    if (state == null || state['status'] != 'playing' || _saving || !widget.cloud.online) return;
    final choices = state['choices'] is Map
        ? Map<String, dynamic>.from(state['choices'] as Map)
        : <String, dynamic>{'me': null, 'sister': null};
    if (choices[_myRole] != null) return;
    choices[_myRole] = choice;
    final next = Map<String, dynamic>.from(state)..['choices'] = choices;
    if (choices['me'] != null && choices['sister'] != null) {
      final result = _rpsWinner(choices['me'].toString(), choices['sister'].toString());
      final scores = _readScores(state['scores']);
      if (result != 'draw') scores[result] = (scores[result] ?? 0) + 1;
      next['scores'] = scores;
      next['lastRound'] = {
        'choices': Map<String, dynamic>.from(choices),
        'winner': result,
      };
      final champion = (scores['me'] ?? 0) >= 3
          ? 'me'
          : ((scores['sister'] ?? 0) >= 3 ? 'sister' : null);
      if (champion != null) {
        next['status'] = 'finished';
        next['winner'] = champion;
      } else {
        next['round'] = _asInt(state['round']) + 1;
        next['choices'] = <String, dynamic>{'me': null, 'sister': null};
      }
    }
    await _saveState(next);
  }

  Future<void> _flipMemoryCard(int index) async {
    final state = _state;
    if (state == null || !_canMove || state['pendingMismatch'] == true) return;
    final deck = (state['deck'] as List? ?? const []).map((value) => value.toString()).toList();
    final revealed = (state['revealed'] as List? ?? const []).map(_asInt).toList();
    final matched = (state['matched'] as List? ?? const []).map(_asInt).toList();
    if (index < 0 || index >= deck.length || matched.contains(index) || revealed.contains(index) || revealed.length >= 2) return;
    revealed.add(index);
    final next = Map<String, dynamic>.from(state);
    if (revealed.length == 2) {
      if (deck[revealed[0]] == deck[revealed[1]]) {
        matched.addAll(revealed);
        next['matched'] = matched;
        next['revealed'] = <int>[];
        final scores = _readScores(state['scores']);
        scores[_myRole] = (scores[_myRole] ?? 0) + 1;
        next['scores'] = scores;
        next['pairsFound'] = _asInt(state['pairsFound']) + 1;
        if (matched.length == deck.length) {
          next['status'] = 'finished';
          final me = scores['me'] ?? 0;
          final sister = scores['sister'] ?? 0;
          next['winner'] = me == sister ? 'draw' : (me > sister ? 'me' : 'sister');
        }
      } else {
        next['pendingMismatch'] = true;
        next['revealed'] = revealed;
      }
    } else {
      next['revealed'] = revealed;
    }
    await _saveState(next);
  }

  Future<void> _hideMemoryCards() async {
    final state = _state;
    if (state == null || !_canMove || state['pendingMismatch'] != true) return;
    final next = Map<String, dynamic>.from(state)
      ..['revealed'] = <int>[]
      ..['pendingMismatch'] = false
      ..['turn'] = _otherRole;
    await _saveState(next);
  }

  Future<void> _guessHangmanLetter(String letter) async {
    final state = _state;
    if (state == null || !_canMove) return;
    final word = state['word']?.toString() ?? '';
    if (word.isEmpty) return;
    final guessed = (state['guessed'] as List? ?? const []).map((value) => value.toString()).toList();
    if (guessed.contains(letter)) return;
    guessed.add(letter);
    final correct = word.contains(letter);
    final wrongCount = _asInt(state['wrongCount']) + (correct ? 0 : 1);
    final allFound = word.runes.every((rune) => guessed.contains(String.fromCharCode(rune)));
    final next = Map<String, dynamic>.from(state)
      ..['guessed'] = guessed
      ..['wrongCount'] = wrongCount
      ..['lastGuess'] = {'letter': letter, 'correct': correct};
    if (allFound) {
      next['status'] = 'finished';
      next['winner'] = _myRole;
      _addScore(next, _myRole);
    } else if (wrongCount >= 7) {
      next['status'] = 'finished';
      next['winner'] = _otherRole;
      _addScore(next, _otherRole);
    } else {
      next['turn'] = _otherRole;
    }
    await _saveState(next);
  }

  Future<void> _submitMathAnswer() async {
    final state = _state;
    if (state == null || !_canMove) return;
    final answer = _parseDigits(_answerController.text);
    if (answer == null) {
      _showMessage('لطفاً پاسخ را به شکل عددی وارد کن.');
      return;
    }
    final order = (state['questionOrder'] as List? ?? const []).map(_asInt).toList();
    final index = _asInt(state['questionIndex']);
    if (index >= order.length) return;
    final question = _mathQuestions[order[index]];
    final correct = answer == question.answer;
    final scores = _readScores(state['scores']);
    if (correct) scores[_myRole] = (scores[_myRole] ?? 0) + 1;
    final next = Map<String, dynamic>.from(state)
      ..['scores'] = scores
      ..['questionIndex'] = index + 1
      ..['lastAnswer'] = {
        'by': _myRole,
        'correct': correct,
        'given': answer,
        'answer': question.answer,
      };
    if (index + 1 >= order.length) {
      next['status'] = 'finished';
      final me = scores['me'] ?? 0;
      final sister = scores['sister'] ?? 0;
      next['winner'] = me == sister ? 'draw' : (me > sister ? 'me' : 'sister');
    } else {
      next['turn'] = _otherRole;
    }
    final saved = await _saveState(next);
    if (saved && mounted) _answerController.clear();
  }

  Future<void> _submitWordChain() async {
    final state = _state;
    if (state == null || !_canMove) return;
    final input = _answerController.text.trim();
    final normalized = _normalizeWord(input);
    if (normalized.length < 2) {
      _showMessage('یک واژه حداقل دو حرفی وارد کن.');
      return;
    }
    final words = (state['words'] as List? ?? const []).map((value) => value.toString()).toList();
    final authors = (state['wordAuthors'] as List? ?? const ['system']).map((value) => value.toString()).toList();
    final normalizedWords = words.map(_normalizeWord).toSet();
    if (normalizedWords.contains(normalized)) {
      _showMessage('این واژه قبلاً استفاده شده است.');
      return;
    }
    final requiredLetter = _lastPersianLetter(words.last);
    if (!_normalizeWord(input).startsWith(requiredLetter)) {
      _showMessage('واژه باید با حرف «$requiredLetter» شروع شود.');
      return;
    }
    words.add(input);
    authors.add(_myRole);
    final scores = _readScores(state['scores']);
    final points = normalized.runes.length >= 5 ? 2 : 1;
    scores[_myRole] = (scores[_myRole] ?? 0) + points;
    final moves = _asInt(state['wordMoves']) + 1;
    final next = Map<String, dynamic>.from(state)
      ..['words'] = words
      ..['wordAuthors'] = authors
      ..['scores'] = scores
      ..['wordMoves'] = moves
      ..['lastWordPoints'] = points;
    if (moves >= 10) {
      next['status'] = 'finished';
      final me = scores['me'] ?? 0;
      final sister = scores['sister'] ?? 0;
      next['winner'] = me == sister ? 'draw' : (me > sister ? 'me' : 'sister');
    } else {
      next['turn'] = _otherRole;
    }
    final saved = await _saveState(next);
    if (saved && mounted) _answerController.clear();
  }

  Future<void> _submitNumberGuess() async {
    final state = _state;
    if (state == null || !_canMove) return;
    final guess = _parseDigits(_answerController.text);
    if (guess == null || guess < 1 || guess > 50) {
      _showMessage('یک عدد بین ۱ تا ۵۰ وارد کن.');
      return;
    }
    final secret = _asInt(state['secretNumber']);
    final attempts = _asInt(state['attempts']) + 1;
    final setter = state['setter']?.toString() ?? _otherRole;
    final correct = guess == secret;
    final next = Map<String, dynamic>.from(state)
      ..['attempts'] = attempts
      ..['lastGuess'] = guess
      ..['lastHint'] = correct ? 'پیداش کردی!' : (guess < secret ? 'بالاتر' : 'پایین‌تر');
    if (correct) {
      next['status'] = 'finished';
      next['winner'] = _myRole;
      _addScore(next, _myRole);
    } else if (attempts >= 7) {
      next['status'] = 'finished';
      next['winner'] = setter;
      _addScore(next, setter);
    }
    final saved = await _saveState(next);
    if (saved && mounted) _answerController.clear();
  }

  Future<void> _tapMineCell(int index) async {
    final state = _state;
    if (state == null || !_canMove) return;
    final mines = (state['mines'] as List? ?? const []).map(_asInt).toSet();
    final revealed = (state['revealed'] as List? ?? const []).map(_asInt).toList();
    if (revealed.contains(index)) return;
    final next = Map<String, dynamic>.from(state);
    if (mines.contains(index)) {
      next['exploded'] = index;
      next['status'] = 'finished';
      next['winner'] = _otherRole;
      _addScore(next, _otherRole);
    } else {
      revealed.add(index);
      next['revealed'] = revealed;
      final scores = _readScores(state['scores']);
      scores[_myRole] = (scores[_myRole] ?? 0) + 1;
      next['scores'] = scores;
      if (revealed.length >= 20) {
        next['status'] = 'finished';
        final me = scores['me'] ?? 0;
        final sister = scores['sister'] ?? 0;
        next['winner'] = me == sister ? 'draw' : (me > sister ? 'me' : 'sister');
      } else {
        next['turn'] = _otherRole;
      }
    }
    await _saveState(next);
  }

  Future<void> _chooseNameFamilyLetter() async {
    final state = _state;
    if (state == null || state['roundScored'] == true || _saving) return;
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF101A29),
      builder: (ctx) => SafeArea(child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(spacing: 8, runSpacing: 8, children: [
          for (final letter in _nameFamilyLetters)
            SizedBox(width: 48, height: 48, child: FilledButton(
              onPressed: () => Navigator.pop(ctx, letter),
              style: FilledButton.styleFrom(backgroundColor: letter == state['letter'] ? widget.game.accent : Colors.white12, foregroundColor: Colors.white),
              child: Text(letter, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            )),
        ]),
      )),
    );
    if (selected == null || !mounted) return;
    final next = Map<String, dynamic>.from(state)
      ..['letter'] = selected
      ..['letterChosenBy'] = _myRole
      ..['answers'] = <String, dynamic>{'me': <String, dynamic>{}, 'sister': <String, dynamic>{}}
      ..['submitted'] = <String, dynamic>{'me': false, 'sister': false}
      ..['manualCategoryScores'] = <String, dynamic>{}
      ..['roundScored'] = false;
    _nameFamilyDraft.clear();
    _nameFamilyManualDraft.clear();
    await _saveState(next);
  }

  Future<void> _submitNameFamilyAnswers() async {
    final state = _state;
    if (state == null || state['status'] != 'playing' || _saving || !widget.cloud.online) return;
    final submitted = state['submitted'] is Map
        ? Map<String, dynamic>.from(state['submitted'] as Map)
        : <String, dynamic>{'me': false, 'sister': false};
    if (submitted[_myRole] == true) return;
    final answers = state['answers'] is Map
        ? Map<String, dynamic>.from(state['answers'] as Map)
        : <String, dynamic>{'me': <String, dynamic>{}, 'sister': <String, dynamic>{}};
    answers[_myRole] = Map<String, dynamic>.from(_nameFamilyDraft);
    submitted[_myRole] = true;
    final next = Map<String, dynamic>.from(state)
      ..['answers'] = answers
      ..['submitted'] = submitted;
    await _saveState(next);
  }

  Future<void> _saveNameFamilyManualScores() async {
    final state = _state;
    if (state == null || state['roundScored'] == true || _saving) return;
    final submitted = state['submitted'] is Map ? state['submitted'] as Map : const {};
    if (submitted['me'] != true || submitted['sister'] != true) return;
    final manual = <String, dynamic>{};
    final totals = <String, int>{'me': 0, 'sister': 0};
    for (final category in _nameFamilyCategories) {
      final values = _nameFamilyManualDraft[category] ?? const <String, int>{};
      final mePoints = (values['me'] ?? 0).clamp(0, 100).toInt();
      final sisterPoints = (values['sister'] ?? 0).clamp(0, 100).toInt();
      manual[category] = <String, int>{'me': mePoints, 'sister': sisterPoints};
      totals['me'] = totals['me']! + mePoints;
      totals['sister'] = totals['sister']! + sisterPoints;
    }
    final scores = _readScores(state['scores']);
    scores['me'] = (scores['me'] ?? 0) + totals['me']!;
    scores['sister'] = (scores['sister'] ?? 0) + totals['sister']!;
    final next = Map<String, dynamic>.from(state)
      ..['manualCategoryScores'] = manual
      ..['roundScored'] = true
      ..['scores'] = scores
      ..['roundPoints'] = totals;
    await _saveState(next);
  }

  Future<void> _nextNameFamilyRound() async {
    final state = _state;
    if (state == null || state['roundScored'] != true || _saving) return;
    final round = _asInt(state['round']) + 1;
    final next = Map<String, dynamic>.from(state);
    if (round > 5) {
      final scores = _readScores(state['scores']);
      next['status'] = 'finished';
      next['winner'] = scores['me'] == scores['sister'] ? 'draw' : (scores['me']! > scores['sister']! ? 'me' : 'sister');
    } else {
      next['round'] = round;
      next['letter'] = _nameFamilyLetters[math.Random().nextInt(_nameFamilyLetters.length)];
      next['answers'] = <String, dynamic>{'me': <String, dynamic>{}, 'sister': <String, dynamic>{}};
      next['submitted'] = <String, dynamic>{'me': false, 'sister': false};
      next['manualCategoryScores'] = <String, dynamic>{};
      next['roundScored'] = false;
      next.remove('roundPoints');
      _nameFamilyDraft.clear();
      _nameFamilyManualDraft.clear();
    }
    await _saveState(next);
  }

  bool get _canMove => _state?['status'] == 'playing' && _state?['turn'] == _myRole && !_saving && widget.cloud.configured && widget.cloud.online;

  void _addScore(Map<String, dynamic> state, String winner) {
    final scores = _readScores(state['scores']);
    scores[winner] = (scores[winner] ?? 0) + 1;
    state['scores'] = scores;
  }

  Future<void> _rematch() async {
    if (_saving || _state == null) return;
    await _startNewGame(previous: _state);
  }

  void _showMessage(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;
    final scores = _readScores(state?['scores']);
    final finished = state?['status'] == 'finished';
    final myTurn = state?['turn'] == _myRole && !finished;
    final winner = state?['winner']?.toString();
    return Scaffold(
      backgroundColor: AppPalette.page,
      appBar: AppBar(
        title: Text(widget.game.title),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        actions: [
          Padding(padding: const EdgeInsetsDirectional.only(end: 14), child: Center(child: _ConnectionPill(online: widget.cloud.online))),
        ],
      ),
      body: SafeArea(
        top: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
                children: [
                  _ScoreBoard(
                    myName: widget.cloud.myDisplayName,
                    otherName: widget.cloud.otherDisplayName,
                    myScore: scores[_myRole] ?? 0,
                    otherScore: scores[_otherRole] ?? 0,
                    myColor: _colors.primary,
                  ),
                  const SizedBox(height: 15),
                  GlassCard(
                    accent: widget.game.accent,
                    child: Row(
                      children: [
                        Icon(finished ? Icons.emoji_events_rounded : Icons.bolt_rounded, color: finished ? Colors.amber : widget.game.accent, size: 24),
                        const SizedBox(width: 10),
                        Expanded(child: Text(finished ? _resultText(winner) : (!widget.cloud.online ? 'ارتباط زنده قطع است؛ بعد از اتصال دوباره می‌توانید ادامه بدهید.' : _gameStatusLine(state, myTurn)), style: const TextStyle(fontWeight: FontWeight.w800, height: 1.5))),
                        if (_saving) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (widget.game.id == 'tic_tac_toe') _buildTicTacToe(state),
                  if (widget.game.id == 'connect_four') _buildConnectFour(state),
                  if (widget.game.id == 'riddles') _buildRiddles(state),
                  if (widget.game.id == 'rock_paper_scissors') _buildRockPaperScissors(state),
                  if (widget.game.id == 'memory_match') _buildMemoryMatch(state),
                  if (widget.game.id == 'hangman') _buildHangman(state),
                  if (widget.game.id == 'math_duel') _buildMathDuel(state),
                  if (widget.game.id == 'word_chain') _buildWordChain(state),
                  if (widget.game.id == 'number_guess') _buildNumberGuess(state),
                  if (widget.game.id == 'mines_duel') _buildMinesDuel(state),
                  if (widget.game.id == 'name_family') _buildNameFamily(state),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: Colors.orangeAccent, fontSize: 12)),
                  ],
                  if (finished) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _rematch,
                        icon: const Icon(Icons.replay_rounded),
                        label: const Text('بازی دوباره'),
                        style: FilledButton.styleFrom(backgroundColor: _colors.primary, foregroundColor: const Color(0xFF061018)),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Text('حرکت‌ها و نتیجه مسابقه به‌صورت زنده برای هر دو نفر ارسال می‌شود.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withValues(alpha: .38), fontSize: 10, height: 1.6)),
                ],
              ),
      ),
    );
  }

  Widget _buildTicTacToe(Map<String, dynamic>? state) {
    final board = (state?['board'] as List? ?? List<String?>.filled(9, null)).map((e) => e?.toString()).toList();
    return GlassCard(
      accent: widget.game.accent,
      padding: const EdgeInsets.all(13),
      child: AspectRatio(
        aspectRatio: 1,
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 9,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 9, mainAxisSpacing: 9),
          itemBuilder: (context, index) {
            final role = index < board.length ? board[index] : null;
            final color = _roleColor(role);
            return Material(
              color: const Color(0xFF121D2B),
              borderRadius: BorderRadius.circular(19),
              child: InkWell(
                borderRadius: BorderRadius.circular(19),
                onTap: _canMove && role == null ? () => _tapTicCell(index) : null,
                child: Center(
                  child: role == null
                      ? Icon(Icons.add_rounded, color: Colors.white.withValues(alpha: .1), size: 25)
                      : Text(role == 'me' ? '×' : '○', style: TextStyle(fontSize: 57, fontWeight: FontWeight.w500, height: 1, color: color)),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildConnectFour(Map<String, dynamic>? state) {
    final board = (state?['board'] as List? ?? List<String?>.filled(42, null)).map((e) => e?.toString()).toList();
    return GlassCard(
      accent: widget.game.accent,
      padding: const EdgeInsets.all(10),
      child: AspectRatio(
        aspectRatio: 7 / 6,
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(color: const Color(0xFF142A48), borderRadius: BorderRadius.circular(20)),
          child: Column(
            children: List.generate(6, (row) => Expanded(
              child: Row(
                children: List.generate(7, (col) {
                  final index = row * 7 + col;
                  final role = index < board.length ? board[index] : null;
                  return Expanded(
                    child: GestureDetector(
                      onTap: _canMove ? () => _dropConnectFour(col) : null,
                      child: Padding(
                        padding: const EdgeInsets.all(3),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: role == null ? const Color(0xFF07111F) : _roleColor(role),
                            border: Border.all(color: Colors.white.withValues(alpha: role == null ? .08 : .28), width: 1.2),
                            boxShadow: role == null ? const [] : [BoxShadow(color: _roleColor(role).withValues(alpha: .22), blurRadius: 8)],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            )),
          ),
        ),
      ),
    );
  }

  Widget _buildRiddles(Map<String, dynamic>? state) {
    final index = _asInt(state?['riddleIndex']);
    final lastResult = state?['lastResult'];
    if (index >= _riddles.length) {
      return GlassCard(accent: widget.game.accent, child: const Center(child: Text('همه چیستان‌ها تمام شدند!')));
    }
    final riddle = _riddles[index];
    return Column(
      children: [
        GlassCard(
          accent: widget.game.accent,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [const Icon(Icons.lightbulb_circle_rounded, color: Color(0xFFFFD36E), size: 25), const SizedBox(width: 8), Text('چیستان ${index + 1} از ${_riddles.length}', style: TextStyle(color: Colors.white.withValues(alpha: .6), fontSize: 12, fontWeight: FontWeight.w800))]),
              const SizedBox(height: 20),
              Text(riddle.question, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, height: 1.8)),
              const SizedBox(height: 10),
              Text(_canMove ? 'جوابت را بنویس و ثبت کن.' : 'تا نوبت بعدی منتظر بمان.', style: TextStyle(color: Colors.white.withValues(alpha: .52), fontSize: 11)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (lastResult is Map)
          GlassCard(
            accent: lastResult['correct'] == true ? Colors.greenAccent : Colors.orangeAccent,
            child: Row(
              children: [
                Icon(lastResult['correct'] == true ? Icons.check_circle_rounded : Icons.info_outline_rounded, color: lastResult['correct'] == true ? Colors.greenAccent : Colors.orangeAccent),
                const SizedBox(width: 9),
                Expanded(child: Text('${_labelFor(lastResult['by']?.toString())}: ${lastResult['correct'] == true ? 'درست بود!' : 'این بار درست نبود.'} جواب: ${lastResult['answer'] ?? ''}', style: const TextStyle(fontSize: 12, height: 1.5))),
              ],
            ),
          ),
        const SizedBox(height: 12),
        TextField(
          controller: _answerController,
          enabled: _canMove,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submitRiddle(),
          decoration: InputDecoration(
            hintText: 'جواب چیستان...',
            suffixIcon: IconButton(onPressed: _canMove ? _submitRiddle : null, icon: const Icon(Icons.send_rounded)),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton(
            onPressed: _canMove ? _submitRiddle : null,
            style: FilledButton.styleFrom(backgroundColor: widget.game.accent, foregroundColor: const Color(0xFF100A1B)),
            child: Text(_canMove ? 'ثبت پاسخ' : 'منتظر نوبت'),
          ),
        ),
      ],
    );
  }

  Widget _buildRockPaperScissors(Map<String, dynamic>? state) {
    final choices = state?['choices'] is Map
        ? Map<String, dynamic>.from(state!['choices'] as Map)
        : <String, dynamic>{};
    final mine = choices[_myRole]?.toString();
    final theirs = choices[_otherRole]?.toString();
    final bothChosen = mine != null && theirs != null;
    final lastRound = state?['lastRound'] is Map
        ? Map<String, dynamic>.from(state!['lastRound'] as Map)
        : null;
    final lastChoices = lastRound?['choices'] is Map
        ? Map<String, dynamic>.from(lastRound!['choices'] as Map)
        : null;
    return Column(
      children: [
        GlassCard(
          accent: widget.game.accent,
          child: Column(
            children: [
              Text('دور ${_asInt(state?['round'])}', style: TextStyle(color: widget.game.accent, fontWeight: FontWeight.w900)),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: _choiceReveal(widget.cloud.myDisplayName, mine, reveal: bothChosen)),
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 9), child: Text('VS', style: TextStyle(color: Colors.white38, fontWeight: FontWeight.w900))),
                  Expanded(child: _choiceReveal(widget.cloud.otherDisplayName, theirs, reveal: bothChosen)),
                ],
              ),
              const SizedBox(height: 14),
              Text(mine == null ? 'انتخابت را بزن؛ انتخاب‌ها تا زمان انتخاب هر دو مخفی‌اند.' : 'انتخاب تو ثبت شد؛ منتظر انتخاب خواهرت/برادرت بمان.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withValues(alpha: .62), fontSize: 12, height: 1.6)),
            ],
          ),
        ),
        if (lastRound != null) ...[
          const SizedBox(height: 10),
          GlassCard(
            accent: widget.game.accent,
            child: Row(children: [
              const Icon(Icons.history_rounded, color: Colors.white54),
              const SizedBox(width: 9),
              Expanded(child: Text('دور قبل: ${_choiceLabel(lastChoices?['me']?.toString())} در برابر ${_choiceLabel(lastChoices?['sister']?.toString())} · ${_winnerLabel(lastRound['winner']?.toString())}', style: const TextStyle(fontSize: 12, height: 1.5))),
            ]),
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            _rpsButton('rock', '✊', 'سنگ'),
            const SizedBox(width: 8),
            _rpsButton('paper', '✋', 'کاغذ'),
            const SizedBox(width: 8),
            _rpsButton('scissors', '✌️', 'قیچی'),
          ],
        ),
        const SizedBox(height: 10),
        Text('هر دور یک امتیاز؛ اولین نفر با ۳ امتیاز برنده می‌شود.', style: TextStyle(color: Colors.white.withValues(alpha: .42), fontSize: 10)),
      ],
    );
  }

  Widget _choiceReveal(String name, String? choice, {required bool reveal}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
        decoration: BoxDecoration(color: widget.game.accent.withValues(alpha: .08), borderRadius: BorderRadius.circular(16), border: Border.all(color: widget.game.accent.withValues(alpha: .18))),
        child: Column(children: [
          Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11)),
          const SizedBox(height: 8),
          Text(reveal && choice != null ? _choiceEmoji(choice) : (choice == null ? '…' : '🔒'), style: const TextStyle(fontSize: 32)),
          const SizedBox(height: 5),
          Text(reveal && choice != null ? _choiceLabel(choice) : (choice == null ? 'هنوز انتخاب نکرده' : 'انتخاب مخفی'), style: TextStyle(color: Colors.white.withValues(alpha: .53), fontSize: 10)),
        ]),
      );

  Widget _rpsButton(String value, String emoji, String label) {
    final choices = _state?['choices'] is Map ? _state!['choices'] as Map : const {};
    final enabled = _state?['status'] == 'playing' && choices[_myRole] == null && !_saving && widget.cloud.online;
    return Expanded(
      child: SizedBox(
        height: 104,
        child: FilledButton(
          onPressed: enabled ? () => _chooseRps(value) : null,
          style: FilledButton.styleFrom(backgroundColor: widget.game.accent.withValues(alpha: .16), foregroundColor: Colors.white, disabledBackgroundColor: Colors.white.withValues(alpha: .04), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: widget.game.accent.withValues(alpha: .24)))),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text(emoji, style: const TextStyle(fontSize: 29)), const SizedBox(height: 6), Text(label, style: const TextStyle(fontWeight: FontWeight.w900))]),
        ),
      ),
    );
  }

  Widget _buildMemoryMatch(Map<String, dynamic>? state) {
    final deck = (state?['deck'] as List? ?? const []).map((value) => value.toString()).toList();
    final revealed = (state?['revealed'] as List? ?? const []).map(_asInt).toSet();
    final matched = (state?['matched'] as List? ?? const []).map(_asInt).toSet();
    final mismatch = state?['pendingMismatch'] == true;
    return Column(children: [
      GlassCard(accent: widget.game.accent, child: Row(children: [
        Expanded(child: Text('جفت‌های پیدا شده: ${_asInt(state?['pairsFound'])} از ۸', style: const TextStyle(fontWeight: FontWeight.w900))),
        Text('نوبت: ${state?['turn'] == _myRole ? 'تو' : widget.cloud.otherDisplayName}', style: TextStyle(color: widget.game.accent, fontWeight: FontWeight.w800, fontSize: 11)),
      ])),
      const SizedBox(height: 12),
      GlassCard(
        accent: widget.game.accent,
        padding: const EdgeInsets.all(10),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 16,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, crossAxisSpacing: 8, mainAxisSpacing: 8),
          itemBuilder: (context, index) {
            final open = revealed.contains(index) || matched.contains(index);
            return Material(
              color: matched.contains(index) ? Colors.greenAccent.withValues(alpha: .13) : (open ? widget.game.accent.withValues(alpha: .14) : const Color(0xFF121D2B)),
              borderRadius: BorderRadius.circular(13),
              child: InkWell(
                borderRadius: BorderRadius.circular(13),
                onTap: !open && _canMove && !mismatch ? () => _flipMemoryCard(index) : null,
                child: Center(child: Text(open && index < deck.length ? deck[index] : '؟', style: TextStyle(fontSize: open ? 27 : 25, color: open ? Colors.white : Colors.white38, fontWeight: FontWeight.w900))),
              ),
            );
          },
        ),
      ),
      if (mismatch) ...[
        const SizedBox(height: 12),
        SizedBox(width: double.infinity, height: 48, child: FilledButton.icon(onPressed: _canMove ? _hideMemoryCards : null, icon: const Icon(Icons.skip_next_rounded), label: const Text('کارت‌ها را ببند و نوبت را واگذار کن'))),
      ],
      const SizedBox(height: 8),
      Text('با پیدا کردن هر جفت، یک امتیاز می‌گیری و نوبتت حفظ می‌شود.', style: TextStyle(color: Colors.white.withValues(alpha: .45), fontSize: 10), textAlign: TextAlign.center),
    ]);
  }

  Widget _buildHangman(Map<String, dynamic>? state) {
    final word = state?['word']?.toString() ?? '';
    final guessed = (state?['guessed'] as List? ?? const []).map((value) => value.toString()).toSet();
    final wrongCount = _asInt(state?['wrongCount']);
    final finished = state?['status'] == 'finished';
    final revealedWord = word.runes.map((rune) {
      final letter = String.fromCharCode(rune);
      return guessed.contains(letter) || finished ? letter : 'ـ';
    }).join('  ');
    return Column(children: [
      GlassCard(accent: widget.game.accent, child: Column(children: [
        Text(revealedWord, textDirection: TextDirection.rtl, style: TextStyle(fontSize: 26, letterSpacing: 3, color: widget.game.accent, fontWeight: FontWeight.w900)),
        const SizedBox(height: 14),
        Row(children: [const Icon(Icons.favorite_rounded, color: Colors.redAccent, size: 18), const SizedBox(width: 7), Expanded(child: Text('فرصت‌های اشتباه: $wrongCount از ۷', style: const TextStyle(fontWeight: FontWeight.w800))), Text('${guessed.length} حرف', style: const TextStyle(color: Colors.white54, fontSize: 10))]),
        const SizedBox(height: 8),
        LinearProgressIndicator(value: wrongCount / 7, color: Colors.redAccent, backgroundColor: Colors.white10, minHeight: 7, borderRadius: BorderRadius.circular(20)),
        if (finished) ...[
          const SizedBox(height: 12),
          Text('کلمه: $word', style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.w900)),
        ],
      ])),
      const SizedBox(height: 12),
      GlassCard(accent: widget.game.accent, child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 6,
        runSpacing: 7,
        children: _persianLetters.map((letter) => SizedBox(
          width: 42,
          height: 42,
          child: FilledButton(
            onPressed: _canMove && !guessed.contains(letter) ? () => _guessHangmanLetter(letter) : null,
            style: FilledButton.styleFrom(padding: EdgeInsets.zero, backgroundColor: widget.game.accent.withValues(alpha: .17), foregroundColor: Colors.white, disabledBackgroundColor: Colors.white.withValues(alpha: .035)),
            child: Text(letter, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          ),
        )).toList(),
      )),
      const SizedBox(height: 8),
      Text('هر نفر در نوبت خود یک حرف انتخاب می‌کند؛ حرف اشتباه یک فرصت کم می‌کند.', style: TextStyle(color: Colors.white.withValues(alpha: .45), fontSize: 10), textAlign: TextAlign.center),
    ]);
  }

  Widget _buildMathDuel(Map<String, dynamic>? state) {
    final order = (state?['questionOrder'] as List? ?? const []).map(_asInt).toList();
    final index = _asInt(state?['questionIndex']);
    final last = state?['lastAnswer'] is Map ? Map<String, dynamic>.from(state!['lastAnswer'] as Map) : null;
    final question = index < order.length ? _mathQuestions[order[index]] : null;
    return Column(children: [
      GlassCard(accent: widget.game.accent, child: Column(children: [
        Text('مسئله ${math.min(index + 1, order.length)} از ${order.length}', style: TextStyle(color: widget.game.accent, fontWeight: FontWeight.w900)),
        const SizedBox(height: 20),
        Text(question?.expression ?? 'همه مسئله‌ها حل شدند!', style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900)),
        const SizedBox(height: 9),
        Text(_canMove ? 'پاسخ را وارد کن.' : 'نوبت ${widget.cloud.otherDisplayName} است.', style: TextStyle(color: Colors.white.withValues(alpha: .55), fontSize: 12)),
      ])),
      const SizedBox(height: 12),
      if (last != null) GlassCard(accent: last['correct'] == true ? Colors.greenAccent : Colors.orangeAccent, child: Row(children: [Icon(last['correct'] == true ? Icons.check_circle_rounded : Icons.info_outline_rounded, color: last['correct'] == true ? Colors.greenAccent : Colors.orangeAccent), const SizedBox(width: 9), Expanded(child: Text('${_labelFor(last['by']?.toString())}: ${last['correct'] == true ? 'درست بود' : 'پاسخ درست ${last['answer']} بود'}', style: const TextStyle(fontSize: 12))) ])),
      const SizedBox(height: 12),
      TextField(controller: _answerController, enabled: _canMove, keyboardType: TextInputType.number, textInputAction: TextInputAction.done, onSubmitted: (_) => _submitMathAnswer(), decoration: InputDecoration(hintText: 'پاسخ عددی', suffixIcon: IconButton(onPressed: _canMove ? _submitMathAnswer : null, icon: const Icon(Icons.send_rounded)))),
      const SizedBox(height: 8),
      Text('۱۰ مسئله؛ هر پاسخ درست یک امتیاز دارد.', style: TextStyle(color: Colors.white.withValues(alpha: .45), fontSize: 10)),
    ]);
  }

  Widget _buildWordChain(Map<String, dynamic>? state) {
    final words = (state?['words'] as List? ?? const []).map((value) => value.toString()).toList();
    final authors = (state?['wordAuthors'] as List? ?? const []).map((value) => value.toString()).toList();
    final requiredLetter = words.isEmpty ? '' : _lastPersianLetter(words.last);
    return Column(children: [
      GlassCard(accent: widget.game.accent, child: Column(children: [
        Text('حرف بعدی', style: TextStyle(color: Colors.white.withValues(alpha: .55), fontSize: 11)),
        const SizedBox(height: 4),
        Text(requiredLetter, style: TextStyle(fontSize: 42, color: widget.game.accent, fontWeight: FontWeight.w900)),
        Text('واژه باید با این حرف شروع شود.', style: TextStyle(color: Colors.white.withValues(alpha: .6), fontSize: 11)),
      ])),
      const SizedBox(height: 12),
      GlassCard(accent: widget.game.accent, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [const Text('زنجیره واژه‌ها', style: TextStyle(fontWeight: FontWeight.w900)), const Spacer(), Text('${_asInt(state?['wordMoves'])} از ۱۰', style: TextStyle(color: widget.game.accent, fontSize: 11, fontWeight: FontWeight.w900))]),
        const SizedBox(height: 10),
        for (var i = 0; i < words.length; i++)
          Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [Container(width: 25, height: 25, decoration: BoxDecoration(color: widget.game.accent.withValues(alpha: .12), borderRadius: BorderRadius.circular(8)), child: Center(child: Text('${i + 1}', style: TextStyle(color: widget.game.accent, fontSize: 10, fontWeight: FontWeight.w900)))), const SizedBox(width: 9), Expanded(child: Text(words[i], style: const TextStyle(fontWeight: FontWeight.w800))), if (i > 0 && i < authors.length) Text(authors[i] == _myRole ? 'تو' : widget.cloud.otherDisplayName, style: TextStyle(color: Colors.white.withValues(alpha: .42), fontSize: 9))])),
      ])),
      const SizedBox(height: 12),
      TextField(controller: _answerController, enabled: _canMove, textDirection: TextDirection.rtl, textInputAction: TextInputAction.done, onSubmitted: (_) => _submitWordChain(), decoration: InputDecoration(hintText: 'یک واژه با حرف «$requiredLetter» بنویس', suffixIcon: IconButton(onPressed: _canMove ? _submitWordChain : null, icon: const Icon(Icons.send_rounded)))),
      const SizedBox(height: 8),
      SizedBox(width: double.infinity, height: 48, child: FilledButton(onPressed: _canMove ? _submitWordChain : null, child: const Text('ثبت واژه'))),
      const SizedBox(height: 7),
      Text('واژه تکراری قبول نیست؛ واژه ۵ حرفی یا بلندتر ۲ امتیاز دارد. اعتبار واژه را خودتان رعایت کنید؛ فرهنگ لغت آنلاین وجود ندارد.', style: TextStyle(color: Colors.white.withValues(alpha: .42), fontSize: 10), textAlign: TextAlign.center),
    ]);
  }

  Widget _buildNumberGuess(Map<String, dynamic>? state) {
    final setter = state?['setter']?.toString();
    final amSetter = setter == _myRole;
    final attempts = _asInt(state?['attempts']);
    final lastGuess = state?['lastGuess'];
    final hint = state?['lastHint']?.toString();
    return Column(children: [
      GlassCard(accent: widget.game.accent, child: Column(children: [
        Icon(Icons.help_outline_rounded, size: 42, color: widget.game.accent),
        const SizedBox(height: 8),
        Text(amSetter ? 'عدد مخفی تو: ${state?['secretNumber'] ?? '—'}' : 'یک عدد بین ۱ تا ۵۰ حدس بزن', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 7),
        Text(amSetter ? 'منتظر حدس ${widget.cloud.otherDisplayName} بمان.' : '۷ فرصت داری؛ از راهنمایی‌ها استفاده کن.', style: TextStyle(color: Colors.white.withValues(alpha: .55), fontSize: 11)),
        const SizedBox(height: 14),
        Text('$attempts / ۷ تلاش', style: TextStyle(color: widget.game.accent, fontWeight: FontWeight.w900)),
        if (lastGuess != null) ...[
          const SizedBox(height: 8),
          Text('حدس آخر: $lastGuess  •  ${hint ?? ''}', style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ])),
      const SizedBox(height: 12),
      if (!amSetter) TextField(controller: _answerController, enabled: _canMove, keyboardType: TextInputType.number, textInputAction: TextInputAction.done, onSubmitted: (_) => _submitNumberGuess(), decoration: InputDecoration(hintText: 'عدد ۱ تا ۵۰', suffixIcon: IconButton(onPressed: _canMove ? _submitNumberGuess : null, icon: const Icon(Icons.send_rounded)))),
      if (amSetter) GlassCard(accent: widget.game.accent, child: const Text('نقش تو: نگهدارنده عدد مخفی؛ پاسخ‌ها را از راهنمایی‌های بازی دنبال کن.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, height: 1.7))),
    ]);
  }

  Widget _buildMinesDuel(Map<String, dynamic>? state) {
    final mines = (state?['mines'] as List? ?? const []).map(_asInt).toSet();
    final revealed = (state?['revealed'] as List? ?? const []).map(_asInt).toSet();
    final finished = state?['status'] == 'finished';
    final exploded = state?['exploded'] == null ? -1 : _asInt(state?['exploded']);
    return Column(children: [
      GlassCard(accent: widget.game.accent, child: Row(children: [const Icon(Icons.flag_rounded, color: Colors.amberAccent), const SizedBox(width: 8), Expanded(child: Text('خانه‌های امن: ${revealed.length} از ۲۰', style: const TextStyle(fontWeight: FontWeight.w900))), Text('۵ مین پنهان', style: TextStyle(color: widget.game.accent, fontSize: 10, fontWeight: FontWeight.w800))])),
      const SizedBox(height: 12),
      GlassCard(accent: widget.game.accent, padding: const EdgeInsets.all(10), child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 25,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5, crossAxisSpacing: 7, mainAxisSpacing: 7),
        itemBuilder: (context, index) {
          final isMine = mines.contains(index);
          final open = revealed.contains(index) || (finished && isMine);
          final explodedHere = index == exploded;
          return Material(
            color: explodedHere ? Colors.redAccent.withValues(alpha: .28) : (open ? (isMine ? Colors.redAccent.withValues(alpha: .2) : Colors.greenAccent.withValues(alpha: .12)) : const Color(0xFF182335)),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: !open && _canMove ? () => _tapMineCell(index) : null,
              child: Center(child: Text(open ? (isMine ? '💣' : '✓') : '·', style: TextStyle(fontSize: open ? 22 : 28, color: open ? (isMine ? Colors.redAccent : Colors.greenAccent) : Colors.white38, fontWeight: FontWeight.w900))),
            ),
          );
        },
      )),
      const SizedBox(height: 8),
      Text('خانه امن یک امتیاز می‌دهد؛ پیدا کردن مین، آن دور را به نفر مقابل می‌بازد.', style: TextStyle(color: Colors.white.withValues(alpha: .45), fontSize: 10), textAlign: TextAlign.center),
    ]);
  }

  Widget _buildNameFamily(Map<String, dynamic>? state) {
    final round = _asInt(state?['round']).clamp(1, 5);
    final letter = state?['letter']?.toString() ?? 'ا';
    final answers = state?['answers'] is Map ? state!['answers'] as Map : const {};
    final myAnswers = answers[_myRole] is Map ? answers[_myRole] as Map : const {};
    final otherAnswers = answers[_otherRole] is Map ? answers[_otherRole] as Map : const {};
    final submitted = state?['submitted'] is Map ? state!['submitted'] as Map : const {};
    final mySubmitted = submitted[_myRole] == true;
    final bothSubmitted = submitted['me'] == true && submitted['sister'] == true;
    final roundScored = state?['roundScored'] == true;
    final storedManual = state?['manualCategoryScores'] is Map ? state!['manualCategoryScores'] as Map : const {};

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      GlassCard(
        accent: widget.game.accent,
        padding: const EdgeInsets.all(18),
        child: Row(children: [
          Container(width: 58, height: 58, alignment: Alignment.center, decoration: BoxDecoration(color: widget.game.accent.withValues(alpha: .15), borderRadius: BorderRadius.circular(18)), child: Text(letter, style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: widget.game.accent))),
          const SizedBox(width: 13),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('دور $round از ۵', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            const Text('برای همه دسته‌ها با همین حرف پاسخ بنویسید.', style: TextStyle(color: Colors.white60, fontSize: 11, height: 1.5)),
          ])),
          IconButton(tooltip: 'انتخاب حرف', onPressed: (!mySubmitted && submitted[_otherRole] != true && !_saving && widget.cloud.online) ? _chooseNameFamilyLetter : null, icon: Icon(Icons.edit_rounded, color: widget.game.accent)),
        ]),
      ),
      Padding(padding: const EdgeInsetsDirectional.only(end: 4, top: 4), child: Text('هر کدام از شما می‌توانید پیش از ثبت پاسخ‌ها حرف دور را انتخاب کنید؛ آخرین انتخاب، حرف مشترک مسابقه است.', style: TextStyle(color: Colors.white.withValues(alpha: .48), fontSize: 10))),
      const SizedBox(height: 12),
      GlassCard(
        accent: widget.game.accent,
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('پاسخ‌های تو', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          for (final category in _nameFamilyCategories) ...[
            TextFormField(
              key: ValueKey('nf-answer-$round-$category'),
              initialValue: myAnswers[category]?.toString() ?? '',
              enabled: !mySubmitted && !_saving,
              textDirection: TextDirection.rtl,
              decoration: InputDecoration(labelText: category, hintText: 'با حرف $letter بنویس', prefixIcon: const Icon(Icons.edit_rounded)),
              onChanged: (value) => _nameFamilyDraft[category] = value,
            ),
            const SizedBox(height: 8),
          ],
          FilledButton.icon(
            onPressed: (!mySubmitted && !_saving && widget.cloud.online) ? _submitNameFamilyAnswers : null,
            icon: Icon(mySubmitted ? Icons.check_circle_rounded : Icons.send_rounded),
            label: Text(mySubmitted ? 'پاسخ‌ها ثبت شده‌اند' : 'ثبت پاسخ‌های من'),
            style: FilledButton.styleFrom(backgroundColor: widget.game.accent, foregroundColor: const Color(0xFF061018), padding: const EdgeInsets.symmetric(vertical: 13)),
          ),
        ]),
      ),
      const SizedBox(height: 12),
      GlassCard(
        accent: bothSubmitted ? Colors.amberAccent : Colors.white24,
        padding: const EdgeInsets.all(15),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('وضعیت ارسال', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 9),
          Row(children: [
            Icon(submitted[_myRole] == true ? Icons.check_circle : Icons.pending, color: submitted[_myRole] == true ? Colors.greenAccent : Colors.white38, size: 18),
            const SizedBox(width: 7),
            const Text('تو', style: TextStyle(fontSize: 12)),
            const Spacer(),
            Icon(submitted[_otherRole] == true ? Icons.check_circle : Icons.pending, color: submitted[_otherRole] == true ? Colors.greenAccent : Colors.white38, size: 18),
            const SizedBox(width: 7),
            Text(widget.cloud.otherDisplayName, style: const TextStyle(fontSize: 12)),
          ]),
          if (!bothSubmitted) ...[
            const SizedBox(height: 8),
            const Text('بعد از ثبت پاسخ هر دو نفر، جدول امتیازدهی دستی باز می‌شود.', style: TextStyle(color: Colors.white54, fontSize: 11, height: 1.5)),
          ],
        ]),
      ),
      if (bothSubmitted) ...[
        const SizedBox(height: 12),
        GlassCard(
          accent: Colors.amberAccent,
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('جدول امتیازدهی دستی', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            const SizedBox(height: 5),
            const Text('پاسخ‌ها را مقایسه کنید و برای هر دسته، امتیاز هر نفر را خودتان وارد کنید.', style: TextStyle(color: Colors.white60, fontSize: 11, height: 1.5)),
            const SizedBox(height: 12),
            for (final category in _nameFamilyCategories) ...[
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: .035), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withValues(alpha: .07))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text(category, style: TextStyle(color: widget.game.accent, fontWeight: FontWeight.w900, fontSize: 12)),
                  const SizedBox(height: 5),
                  Text('تو: ${myAnswers[category]?.toString().trim().isEmpty == true ? '—' : myAnswers[category] ?? '—'}', style: const TextStyle(fontSize: 11)),
                  Text('${widget.cloud.otherDisplayName}: ${otherAnswers[category]?.toString().trim().isEmpty == true ? '—' : otherAnswers[category] ?? '—'}', style: const TextStyle(fontSize: 11, color: Colors.white70)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: TextFormField(
                      key: ValueKey('nf-score-$round-$category-$_myRole-${(storedManual[category] is Map ? storedManual[category][_myRole] : null) ?? 0}'),
                      initialValue: ((storedManual[category] is Map ? storedManual[category][_myRole] : null) ?? 0).toString(),
                      enabled: !roundScored,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'امتیاز تو', isDense: true, prefixIcon: Icon(Icons.person_outline_rounded)),
                      onChanged: (value) => _setNameFamilyDraftScore(category, _myRole, value),
                    )),
                    const SizedBox(width: 9),
                    Expanded(child: TextFormField(
                      key: ValueKey('nf-score-$round-$category-$_otherRole-${(storedManual[category] is Map ? storedManual[category][_otherRole] : null) ?? 0}'),
                      initialValue: ((storedManual[category] is Map ? storedManual[category][_otherRole] : null) ?? 0).toString(),
                      enabled: !roundScored,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: 'امتیاز ${widget.cloud.otherDisplayName}', isDense: true, prefixIcon: const Icon(Icons.favorite_border_rounded)),
                      onChanged: (value) => _setNameFamilyDraftScore(category, _otherRole, value),
                    )),
                  ]),
                ]),
              ),
              const SizedBox(height: 8),
            ],
            if (!roundScored)
              FilledButton.icon(
                onPressed: _saving || !widget.cloud.online ? null : _saveNameFamilyManualScores,
                icon: const Icon(Icons.calculate_rounded),
                label: const Text('ثبت امتیازهای دستی این دور'),
                style: FilledButton.styleFrom(backgroundColor: Colors.amberAccent, foregroundColor: const Color(0xFF17120A), padding: const EdgeInsets.symmetric(vertical: 13)),
              )
            else ...[
              Text('امتیاز این دور — تو: ${_asInt((state?['roundPoints'] as Map?)?[_myRole])}  |  ${widget.cloud.otherDisplayName}: ${_asInt((state?['roundPoints'] as Map?)?[_otherRole])}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: _saving ? null : _nextNameFamilyRound,
                icon: const Icon(Icons.skip_next_rounded),
                label: Text(round == 5 ? 'پایان مسابقه' : 'رفتن به حرف بعدی'),
                style: FilledButton.styleFrom(backgroundColor: widget.game.accent, foregroundColor: const Color(0xFF061018), padding: const EdgeInsets.symmetric(vertical: 13)),
              ),
            ],
          ]),
        ),
      ],
    ]);
  }

  void _setNameFamilyDraftScore(String category, String role, String value) {
    final parsed = _parseDigits(value) ?? 0;
    final values = _nameFamilyManualDraft.putIfAbsent(category, () => <String, int>{'me': 0, 'sister': 0});
    values[role] = parsed.clamp(0, 100).toInt();
  }

  String _gameStatusLine(Map<String, dynamic>? state, bool myTurn) {
    if (widget.game.id == 'name_family') {
      final submitted = state?['submitted'] is Map ? state!['submitted'] as Map : const {};
      if (state?['roundScored'] == true) return 'امتیازهای این دور ثبت شد؛ برای دور بعد آماده شوید.';
      if (submitted[_myRole] == true) return 'پاسخ‌هایت ثبت شد؛ منتظر پاسخ ${widget.cloud.otherDisplayName} بمان.';
      return 'حرف «${state?['letter'] ?? ''}»؛ پاسخ هفت دسته را وارد کن.';
    }
    if (widget.game.id == 'rock_paper_scissors') {
      final choices = state?['choices'] is Map ? state!['choices'] as Map : const {};
      return choices[_myRole] == null ? 'انتخابت را ثبت کن؛ انتخاب‌ها هم‌زمان و مخفی هستند.' : 'انتخابت ثبت شد؛ منتظر ${widget.cloud.otherDisplayName} بمان.';
    }
    if (widget.game.id == 'memory_match' && state?['pendingMismatch'] == true) return myTurn ? 'دو کارت را ببین و سپس نوبت را واگذار کن.' : 'کارت‌ها باز هستند؛ منتظر پایان نوبت باش.';
    if (widget.game.id == 'memory_match' && (state?['revealed'] as List? ?? const []).isNotEmpty && myTurn) return 'یک کارت دیگر انتخاب کن.';
    if (widget.game.id == 'number_guess' && state?['setter'] == _myRole) return 'عدد مخفی را نگه دار؛ ${widget.cloud.otherDisplayName} در حال حدس زدن است.';
    if (myTurn) return 'نوبت توست؛ حرکت بعدی با توست.';
    return 'نوبت ${widget.cloud.otherDisplayName} است؛ منتظر حرکت او باش.';
  }

  String _choiceEmoji(String choice) => switch (choice) {
        'rock' => '✊',
        'paper' => '✋',
        'scissors' => '✌️',
        _ => '❔',
      };

  String _choiceLabel(String? choice) => switch (choice) {
        'rock' => 'سنگ',
        'paper' => 'کاغذ',
        'scissors' => 'قیچی',
        _ => '—',
      };

  String _winnerLabel(String? winner) => winner == 'draw' ? 'مساوی' : (winner == _myRole ? 'تو بردی' : 'طرف مقابل برد');

  String _rpsWinner(String me, String sister) {
    if (me == sister) return 'draw';
    final meWins = (me == 'rock' && sister == 'scissors') || (me == 'paper' && sister == 'rock') || (me == 'scissors' && sister == 'paper');
    return meWins ? 'me' : 'sister';
  }

  Color _roleColor(String? role) => role == 'me' ? _colors.primary : const Color(0xFFFF76A7);

  String _labelFor(String? role) => role == _myRole ? widget.cloud.myDisplayName : widget.cloud.otherDisplayName;

  String _resultText(String? winner) {
    if (winner == null || winner == 'draw') return 'مساوی شدید! یک دور دیگر بازی کنید.';
    if (winner == _myRole) return 'آفرین! این دور را بردی 🏆';
    return 'این دور را ${widget.cloud.otherDisplayName} برد! دور بعد جبران کن 💜';
  }
}

class _SoloGameScreen extends StatefulWidget {
  const _SoloGameScreen({required this.game, required this.theme});
  final _GameDefinition game;
  final AppThemeChoice theme;

  @override
  State<_SoloGameScreen> createState() => _SoloGameScreenState();
}

class _SoloGameScreenState extends State<_SoloGameScreen> {
  final TextEditingController _answerController = TextEditingController();
  final Map<String, TextEditingController> _familyControllers = {
    for (final category in _nameFamilyCategories) category: TextEditingController(),
  };
  final math.Random _random = math.Random();
  Timer? _familyTimer;

  int _score = 0;
  int _round = 1;
  bool _finished = false;
  bool _busy = false;
  String _status = 'بازی آماده است؛ شروع کن!';

  List<String?> _ticBoard = List<String?>.filled(9, null);
  List<String?> _connectBoard = List<String?>.filled(42, null);
  List<int> _riddleOrder = [];
  int _riddleIndex = 0;
  List<int> _mathOrder = [];
  int _mathIndex = 0;
  int _rpsRound = 1;
  String _lastRpsResult = '';
  List<String> _memoryDeck = [];
  final Set<int> _memoryRevealed = {};
  final Set<int> _memoryMatched = {};
  int _memoryAttempts = 0;
  String _hangmanWord = '';
  final Set<String> _hangmanGuessed = {};
  int _hangmanWrong = 0;
  List<String> _chainWords = [];
  int _chainMoves = 0;
  int _secretNumber = 0;
  int _numberAttempts = 0;
  String _numberHint = '';
  final Set<int> _mines = {};
  final Set<int> _mineRevealed = {};
  int? _explodedMine;
  String _familyLetter = 'ا';
  int _familySeconds = 60;
  bool _familyScored = false;
  Map<String, int> _familyBreakdown = {};
  Map<String, Map<String, String>> _familyBotAnswers = {};
  Map<String, Map<String, int>> _familyBotBreakdowns = {};
  Map<String, int> _familyBotTotals = {'ربات اول': 0, 'ربات دوم': 0};

  @override
  void initState() {
    super.initState();
    _initializeGame();
  }

  @override
  void dispose() {
    _familyTimer?.cancel();
    _answerController.dispose();
    for (final controller in _familyControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _initializeGame({bool resetScore = false}) {
    _familyTimer?.cancel();
    if (resetScore) _score = 0;
    _round = 1;
    _finished = false;
    _busy = false;
    _status = 'بازی آماده است؛ شروع کن!';
    _answerController.clear();
    _ticBoard = List<String?>.filled(9, null);
    _connectBoard = List<String?>.filled(42, null);
    _riddleOrder = List<int>.generate(_riddles.length, (index) => index)..shuffle(_random);
    _riddleIndex = 0;
    _mathOrder = List<int>.generate(_mathQuestions.length, (index) => index)..shuffle(_random);
    _mathIndex = 0;
    _rpsRound = 1;
    _lastRpsResult = '';
    _memoryDeck = List<String>.from(_memorySymbols)..addAll(_memorySymbols);
    _memoryDeck.shuffle(_random);
    _memoryRevealed.clear();
    _memoryMatched.clear();
    _memoryAttempts = 0;
    final words = List<String>.from(_hangmanWords)..shuffle(_random);
    _hangmanWord = _normalizeWord(words.first);
    _hangmanGuessed.clear();
    _hangmanWrong = 0;
    final seeds = List<String>.from(_wordSeeds)..shuffle(_random);
    _chainWords = [seeds.first];
    _chainMoves = 0;
    _secretNumber = _random.nextInt(50) + 1;
    _numberAttempts = 0;
    _numberHint = '';
    _mines.clear();
    final positions = List<int>.generate(25, (index) => index)..shuffle(_random);
    _mines.addAll(positions.take(5));
    _mineRevealed.clear();
    _explodedMine = null;
    _familyLetter = _nameFamilyLetters[_random.nextInt(_nameFamilyLetters.length)];
    _familySeconds = 60;
    _familyScored = false;
    _familyBreakdown = {};
    _familyBotAnswers = {};
    _familyBotBreakdowns = {};
    _familyBotTotals = {'ربات اول': 0, 'ربات دوم': 0};
    for (final controller in _familyControllers.values) {
      controller.clear();
    }
    if (widget.game.id == 'name_family') _startFamilyTimer();
  }

  void _restart() {
    setState(() => _initializeGame(resetScore: false));
  }

  void _startFamilyTimer() {
    _familyTimer?.cancel();
    _familyTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _familyScored || _finished) {
        timer.cancel();
        return;
      }
      if (_familySeconds <= 1) {
        timer.cancel();
        setState(() => _familySeconds = 0);
        _submitSoloNameFamily(autoSubmitted: true);
      } else {
        setState(() => _familySeconds--);
      }
    });
  }

  List<List<int>> get _ticLines => const [
        [0, 1, 2], [3, 4, 5], [6, 7, 8],
        [0, 3, 6], [1, 4, 7], [2, 5, 8],
        [0, 4, 8], [2, 4, 6],
      ];

  void _tapSoloTic(int index) {
    if (_finished || _ticBoard[index] != null) return;
    setState(() {
      _ticBoard[index] = 'me';
      if (_findWinner(_ticBoard, _ticLines) == 'me') {
        _score++;
        _finished = true;
        _status = 'بردی! حرکت‌های هوشمندانه‌ای بود 🏆';
        return;
      }
      if (_ticBoard.every((cell) => cell != null)) {
        _finished = true;
        _status = 'مساوی شد؛ یک دور دیگر امتحان کن.';
        return;
      }
      final botMove = _bestTicMove();
      if (botMove >= 0) _ticBoard[botMove] = 'bot';
      if (_findWinner(_ticBoard, _ticLines) == 'bot') {
        _finished = true;
        _status = 'این دور را حریف هوشمند برد؛ دوباره تلاش کن.';
      } else if (_ticBoard.every((cell) => cell != null)) {
        _finished = true;
        _status = 'مساوی شد؛ بازی خوبی بود.';
      } else {
        _status = 'حرکت حریف انجام شد؛ نوبت توست.';
      }
    });
  }

  int _bestTicMove() {
    final empty = List<int>.generate(9, (index) => index).where((index) => _ticBoard[index] == null).toList();
    for (final role in ['bot', 'me']) {
      for (final index in empty) {
        final copy = List<String?>.from(_ticBoard)..[index] = role;
        if (_findWinner(copy, _ticLines) == role) return index;
      }
    }
    if (_ticBoard[4] == null) return 4;
    final corners = [0, 2, 6, 8].where((index) => _ticBoard[index] == null).toList();
    if (corners.isNotEmpty) return corners[_random.nextInt(corners.length)];
    return empty.isEmpty ? -1 : empty[_random.nextInt(empty.length)];
  }

  void _dropSoloConnect(int column) {
    if (_finished) return;
    setState(() {
      if (!_placeConnect(_connectBoard, column, 'me')) return;
      var winner = _connectWinner(_connectBoard);
      if (winner == 'me') {
        _score++;
        _finished = true;
        _status = 'چهار مهره را ردیف کردی؛ آفرین!';
        return;
      }
      if (_connectBoard.every((cell) => cell != null)) {
        _finished = true;
        _status = 'صفحه پر شد؛ مساوی!';
        return;
      }
      final botColumn = _bestConnectMove();
      if (botColumn >= 0) _placeConnect(_connectBoard, botColumn, 'bot');
      winner = _connectWinner(_connectBoard);
      if (winner == 'bot') {
        _finished = true;
        _status = 'حریف هوشمند چهار مهره را ردیف کرد.';
      } else if (_connectBoard.every((cell) => cell != null)) {
        _finished = true;
        _status = 'صفحه پر شد؛ مساوی!';
      } else {
        _status = 'حریف حرکت کرد؛ نوبت توست.';
      }
    });
  }

  bool _placeConnect(List<String?> board, int col, String role) {
    if (col < 0 || col >= 7) return false;
    for (var row = 5; row >= 0; row--) {
      final index = row * 7 + col;
      if (board[index] == null) {
        board[index] = role;
        return true;
      }
    }
    return false;
  }

  int _bestConnectMove() {
    final valid = List<int>.generate(7, (index) => index).where((column) => _connectBoard[column] == null).toList();
    for (final role in ['bot', 'me']) {
      for (final column in valid) {
        final copy = List<String?>.from(_connectBoard);
        _placeConnect(copy, column, role);
        if (_connectWinner(copy) == role) return column;
      }
    }
    const preferred = [3, 2, 4, 1, 5, 0, 6];
    for (final column in preferred) {
      if (valid.contains(column)) return column;
    }
    return valid.isEmpty ? -1 : valid[_random.nextInt(valid.length)];
  }

  String? _connectWinner(List<String?> board) {
    for (var row = 0; row < 6; row++) {
      for (var col = 0; col < 7; col++) {
        final role = board[row * 7 + col];
        if (role == null) continue;
        for (final direction in const [(0, 1), (1, 0), (1, 1), (1, -1)]) {
          var count = 1;
          for (var step = 1; step < 4; step++) {
            final r = row + direction.$1 * step;
            final c = col + direction.$2 * step;
            if (r < 0 || r >= 6 || c < 0 || c >= 7 || board[r * 7 + c] != role) break;
            count++;
          }
          if (count >= 4) return role;
        }
      }
    }
    return null;
  }

  void _submitSoloRiddle() {
    if (_finished || _riddleIndex >= _riddleOrder.length) return;
    final answer = _normalizeAnswer(_answerController.text);
    if (answer.isEmpty) return;
    final riddle = _riddles[_riddleOrder[_riddleIndex]];
    final correct = riddle.answers.map(_normalizeAnswer).contains(answer);
    setState(() {
      if (correct) _score++;
      _riddleIndex++;
      _answerController.clear();
      _status = correct ? 'درست گفتی! یک امتیاز گرفتی.' : 'جواب درست: ${riddle.answers.first}';
      if (_riddleIndex >= _riddleOrder.length) {
        _finished = true;
        _status = 'چیستان‌ها تمام شد؛ ${_score} امتیاز گرفتی.';
      }
    });
  }

  void _playSoloRps(String playerChoice) {
    if (_finished) return;
    const choices = ['rock', 'paper', 'scissors'];
    final botChoice = choices[_random.nextInt(choices.length)];
    final result = playerChoice == botChoice
        ? 'مساوی'
        : (((playerChoice == 'rock' && botChoice == 'scissors') || (playerChoice == 'paper' && botChoice == 'rock') || (playerChoice == 'scissors' && botChoice == 'paper')) ? 'بردی' : 'حریف برد');
    setState(() {
      if (result == 'بردی') _score++;
      _lastRpsResult = 'تو ${_soloChoiceEmoji(playerChoice)}  |  حریف ${_soloChoiceEmoji(botChoice)}  ·  $result';
      if (_rpsRound >= 5) {
        _finished = true;
        _status = '۵ دور تمام شد؛ در مجموع $_score برد داشتی.';
      } else {
        _rpsRound++;
        _status = result == 'بردی' ? 'این دور را بردی!' : result == 'مساوی' ? 'این دور مساوی شد.' : 'این دور را حریف برد.';
      }
    });
  }

  String _soloChoiceEmoji(String choice) => switch (choice) {
        'rock' => '✊',
        'paper' => '✋',
        _ => '✌️',
      };

  Future<void> _flipSoloMemory(int index) async {
    if (_finished || _busy || _memoryRevealed.contains(index) || _memoryMatched.contains(index)) return;
    setState(() {
      _memoryRevealed.add(index);
      if (_memoryRevealed.length == 2) {
        _memoryAttempts++;
        _busy = true;
      }
    });
    if (_memoryRevealed.length == 2) {
      await Future<void>.delayed(const Duration(milliseconds: 750));
      if (!mounted) return;
      setState(() {
        final pair = _memoryRevealed.toList();
        if (_memoryDeck[pair[0]] == _memoryDeck[pair[1]]) {
          _memoryMatched.addAll(pair);
          _score++;
          _status = 'یک جفت پیدا کردی!';
        } else {
          _status = 'این دو کارت یکی نبودند؛ دوباره تلاش کن.';
        }
        _memoryRevealed.clear();
        _busy = false;
        if (_memoryMatched.length == _memoryDeck.length) {
          _finished = true;
          _status = 'همه جفت‌ها پیدا شدند! $_score جفت در $_memoryAttempts تلاش.';
        }
      });
    }
  }

  void _guessSoloHangman(String letter) {
    if (_finished || _hangmanGuessed.contains(letter)) return;
    setState(() {
      _hangmanGuessed.add(letter);
      if (!_hangmanWord.contains(letter)) _hangmanWrong++;
      final found = _hangmanWord.runes.every((rune) => _hangmanGuessed.contains(String.fromCharCode(rune)));
      if (found) {
        _score += math.max(1, 7 - _hangmanWrong).toInt();
        _finished = true;
        _status = 'کلمه را پیدا کردی: $_hangmanWord';
      } else if (_hangmanWrong >= 7) {
        _finished = true;
        _status = 'فرصت‌ها تمام شد؛ کلمه «$_hangmanWord» بود.';
      }
    });
  }

  void _submitSoloMath() {
    if (_finished || _mathIndex >= 10) return;
    final answer = _parseDigits(_answerController.text);
    if (answer == null) return;
    final question = _mathQuestions[_mathOrder[_mathIndex]];
    final correct = answer == question.answer;
    setState(() {
      if (correct) _score++;
      _mathIndex++;
      _answerController.clear();
      _status = correct ? 'پاسخ درست بود!' : 'پاسخ درست ${question.answer} بود.';
      if (_mathIndex >= 10) {
        _finished = true;
        _status = 'آزمون ریاضی تمام شد؛ از ۱۰ سؤال، $_score امتیاز گرفتی.';
      }
    });
  }

  void _submitSoloWordChain() {
    if (_finished || _chainMoves >= 10) return;
    final input = _answerController.text.trim();
    final normalized = _normalizeWord(input);
    if (normalized.length < 2) return;
    final used = _chainWords.map(_normalizeWord).toSet();
    final required = _lastPersianLetter(_chainWords.last);
    if (!normalized.startsWith(required)) {
      setState(() => _status = 'واژه باید با «$required» شروع شود.');
      return;
    }
    if (used.contains(normalized)) {
      setState(() => _status = 'این واژه قبلاً گفته شده است.');
      return;
    }
    setState(() {
      _chainWords.add(input);
      _chainMoves++;
      _score++;
      _answerController.clear();
      final needed = _lastPersianLetter(input);
      final candidates = _soloWordPool.where((word) => _normalizeWord(word).startsWith(needed) && !used.contains(_normalizeWord(word)) && _normalizeWord(word) != normalized).toList();
      if (candidates.isEmpty) {
        _finished = true;
        _score += 2;
        _status = 'حریف واژه‌ای با حرف «$needed» پیدا نکرد؛ تو برنده شدی!';
        return;
      }
      candidates.shuffle(_random);
      _chainWords.add(candidates.first);
      _chainMoves++;
      if (_chainMoves >= 10) {
        _finished = true;
        _status = 'زنجیره کامل شد؛ $_score امتیاز گرفتی.';
      } else {
        _status = 'حریف گفت «${candidates.first}»؛ حالا با «${_lastPersianLetter(candidates.first)}» ادامه بده.';
      }
    });
  }

  void _submitSoloNumberGuess() {
    if (_finished) return;
    final guess = _parseDigits(_answerController.text);
    if (guess == null || guess < 1 || guess > 50) {
      setState(() => _status = 'یک عدد بین ۱ تا ۵۰ وارد کن.');
      return;
    }
    setState(() {
      _numberAttempts++;
      _answerController.clear();
      if (guess == _secretNumber) {
        _score += math.max(1, 8 - _numberAttempts).toInt();
        _finished = true;
        _numberHint = 'درست پیدا کردی!';
        _status = 'عدد مخفی $_secretNumber بود؛ در $_numberAttempts تلاش پیدایش کردی.';
      } else if (_numberAttempts >= 7) {
        _finished = true;
        _numberHint = guess < _secretNumber ? 'عدد بالاتر بود' : 'عدد پایین‌تر بود';
        _status = '۷ تلاش تمام شد؛ عدد مخفی $_secretNumber بود.';
      } else {
        _numberHint = guess < _secretNumber ? 'بالاتر برو' : 'پایین‌تر بیا';
        _status = _numberHint;
      }
    });
  }

  void _tapSoloMine(int index) {
    if (_finished || _mineRevealed.contains(index)) return;
    setState(() {
      if (_mines.contains(index)) {
        _explodedMine = index;
        _finished = true;
        _status = 'مین پیدا شد! ${_mineRevealed.length} خانه امن را باز کردی.';
      } else {
        _mineRevealed.add(index);
        _score++;
        _status = 'خانه امن بود؛ یک امتیاز گرفتی.';
        if (_mineRevealed.length >= 20) {
          _finished = true;
          _status = 'همه خانه‌های امن را پیدا کردی!';
        }
      }
    });
  }

  void _submitSoloNameFamily({bool autoSubmitted = false}) {
    if (_familyScored || _finished) return;
    _familyTimer?.cancel();
    final seen = <String>{};
    final breakdown = <String, int>{};
    var total = 0;
    for (final category in _nameFamilyCategories) {
      final answer = _familyControllers[category]!.text.trim();
      final normalized = _normalizeWord(answer);
      var points = 0;
      if (normalized.isNotEmpty && normalized.startsWith(_familyLetter)) {
        if (seen.add(normalized)) {
          points = 10;
        } else {
          points = 5;
        }
      }
      breakdown[category] = points;
      total += points;
    }
    final botAnswers = <String, Map<String, String>>{};
    final botBreakdowns = <String, Map<String, int>>{};
    final botTotals = <String, int>{};
    for (final botName in ['ربات اول', 'ربات دوم']) {
      final answers = <String, String>{};
      final botSeen = <String>{};
      final pointsByCategory = <String, int>{};
      var botTotal = 0;
      for (final category in _nameFamilyCategories) {
        final answer = _botFamilyAnswer(category, _familyLetter, botName == 'ربات اول' ? 0 : 1);
        answers[category] = answer;
        final normalized = _normalizeWord(answer);
        final points = normalized.isNotEmpty && normalized.startsWith(_familyLetter)
            ? (botSeen.add(normalized) ? 10 : 5) : 0;
        pointsByCategory[category] = points;
        botTotal += points;
      }
      botAnswers[botName] = answers;
      botBreakdowns[botName] = pointsByCategory;
      botTotals[botName] = botTotal;
    }
    setState(() {
      _familyScored = true;
      _familyBreakdown = breakdown;
      _familyBotAnswers = botAnswers;
      _familyBotBreakdowns = botBreakdowns;
      for (final entry in botTotals.entries) {
        _familyBotTotals[entry.key] = (_familyBotTotals[entry.key] ?? 0) + entry.value;
      }
      _score += total;
      _status = autoSubmitted ? 'زمان تمام شد؛ امتیازها خودکار محاسبه شدند.' : 'پاسخ‌ها ثبت شد و امتیازها خودکار محاسبه شدند.';
      if (_round >= 5) {
        _finished = true;
        _status = '۵ دور اسم‌فامیل تمام شد؛ مجموع امتیاز تو $_score است.';
      }
    });
  }

  void _nextSoloNameFamilyRound() {
    if (_finished) return;
    setState(() {
      _round++;
      _familyLetter = _nameFamilyLetters[_random.nextInt(_nameFamilyLetters.length)];
      _familyScored = false;
      _familyBreakdown = {};
      _familyBotAnswers = {};
      _familyBotBreakdowns = {};
      _familySeconds = 60;
      for (final controller in _familyControllers.values) {
        controller.clear();
      }
      _status = 'حرف تازه انتخاب شد؛ شروع کن!';
      _startFamilyTimer();
    });
  }

  Widget _soloPanel({required Widget child, EdgeInsets padding = const EdgeInsets.all(16)}) =>
      GlassCard(accent: widget.game.accent, padding: padding, child: child);

  Widget _soloTextInput({String? hint, TextInputType? keyboardType, VoidCallback? onSend, bool enabled = true}) => TextField(
        controller: _answerController,
        enabled: enabled && !_finished,
        keyboardType: keyboardType,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => onSend?.call(),
        decoration: InputDecoration(
          hintText: hint,
          suffixIcon: IconButton(onPressed: enabled && !_finished ? onSend : null, icon: const Icon(Icons.send_rounded)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.page,
      appBar: AppBar(
        title: Text(widget.game.title),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        actions: const [Padding(padding: EdgeInsetsDirectional.only(end: 14), child: Center(child: _MiniTag(text: 'تک‌نفره · آفلاین', color: Colors.greenAccent)))],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
          children: [
            _soloPanel(
              child: Row(children: [
                Container(width: 48, height: 48, decoration: BoxDecoration(color: widget.game.accent.withValues(alpha: .14), borderRadius: BorderRadius.circular(15)), child: Icon(widget.game.icon, color: widget.game.accent, size: 26)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('چالش تک‌نفره', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 3),
                  Text('امتیاز: $_score', style: TextStyle(color: widget.game.accent, fontWeight: FontWeight.w900, fontSize: 12)),
                ])),
                if (widget.game.id == 'name_family') _MiniTag(text: '$_familySeconds ثانیه', color: _familySeconds <= 10 ? Colors.redAccent : widget.game.accent),
              ]),
            ),
            const SizedBox(height: 12),
            _soloPanel(child: Text(_status, style: const TextStyle(fontWeight: FontWeight.w800, height: 1.6))),
            const SizedBox(height: 14),
            if (widget.game.id == 'tic_tac_toe') _buildSoloTic(),
            if (widget.game.id == 'connect_four') _buildSoloConnect(),
            if (widget.game.id == 'riddles') _buildSoloRiddles(),
            if (widget.game.id == 'rock_paper_scissors') _buildSoloRps(),
            if (widget.game.id == 'memory_match') _buildSoloMemory(),
            if (widget.game.id == 'hangman') _buildSoloHangman(),
            if (widget.game.id == 'math_duel') _buildSoloMath(),
            if (widget.game.id == 'word_chain') _buildSoloWordChain(),
            if (widget.game.id == 'number_guess') _buildSoloNumber(),
            if (widget.game.id == 'mines_duel') _buildSoloMines(),
            if (widget.game.id == 'name_family') _buildSoloNameFamily(),
            if (_finished) ...[
              const SizedBox(height: 16),
              FilledButton.icon(onPressed: _restart, icon: const Icon(Icons.replay_rounded), label: const Text('دور تازه')),
            ],
            const SizedBox(height: 8),
            Text('این حالت بدون اینترنت و بدون اتصال به حساب دوم اجرا می‌شود.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withValues(alpha: .38), fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildSoloTic() => _soloPanel(
        child: AspectRatio(
          aspectRatio: 1,
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 9,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8),
            itemBuilder: (context, index) {
              final role = _ticBoard[index];
              return Material(
                color: const Color(0xFF121D2B),
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: !_finished && role == null ? () => _tapSoloTic(index) : null,
                  child: Center(child: Text(role == null ? '·' : (role == 'me' ? '×' : '○'), style: TextStyle(fontSize: 55, color: role == null ? Colors.white24 : (role == 'me' ? widget.game.accent : Colors.pinkAccent), fontWeight: FontWeight.w900))),
                ),
              );
            },
          ),
        ),
      );

  Widget _buildSoloConnect() => _soloPanel(
        padding: const EdgeInsets.all(9),
        child: AspectRatio(
          aspectRatio: 7 / 6,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: const Color(0xFF142A48), borderRadius: BorderRadius.circular(18)),
            child: Column(children: List.generate(6, (row) => Expanded(child: Row(children: List.generate(7, (col) {
              final role = _connectBoard[row * 7 + col];
              return Expanded(child: GestureDetector(
                onTap: _finished ? null : () => _dropSoloConnect(col),
                child: Padding(padding: const EdgeInsets.all(3), child: AnimatedContainer(duration: const Duration(milliseconds: 160), decoration: BoxDecoration(shape: BoxShape.circle, color: role == null ? const Color(0xFF07111F) : (role == 'me' ? widget.game.accent : Colors.pinkAccent), border: Border.all(color: Colors.white12)))),
              ));
            }))))),
          ),
        ),
      );

  Widget _buildSoloRiddles() {
    if (_riddleIndex >= _riddleOrder.length) return _soloPanel(child: const Text('چیستان‌ها تمام شدند.'));
    final riddle = _riddles[_riddleOrder[_riddleIndex]];
    return Column(children: [
      _soloPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('چیستان ${_riddleIndex + 1} از ۱۰', style: TextStyle(color: widget.game.accent, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        Text(riddle.question, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, height: 1.8)),
      ])),
      const SizedBox(height: 12),
      _soloTextInput(hint: 'پاسخت را بنویس', onSend: _submitSoloRiddle),
      const SizedBox(height: 10),
      FilledButton(onPressed: _finished ? null : _submitSoloRiddle, child: const Text('ثبت پاسخ')),
    ]);
  }

  Widget _buildSoloRps() => _soloPanel(child: Column(children: [
        Text('دور $_rpsRound از ۵', style: TextStyle(color: widget.game.accent, fontWeight: FontWeight.w900)),
        const SizedBox(height: 14),
        if (_lastRpsResult.isNotEmpty) Text(_lastRpsResult, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _choiceButton('سنگ', '✊', 'rock')),
          const SizedBox(width: 8),
          Expanded(child: _choiceButton('کاغذ', '✋', 'paper')),
          const SizedBox(width: 8),
          Expanded(child: _choiceButton('قیچی', '✌️', 'scissors')),
        ]),
      ]));

  Widget _choiceButton(String label, String emoji, String choice) => OutlinedButton(
        onPressed: _finished ? null : () => _playSoloRps(choice),
        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), side: BorderSide(color: widget.game.accent.withValues(alpha: .4))),
        child: Column(children: [Text(emoji, style: const TextStyle(fontSize: 25)), const SizedBox(height: 4), Text(label, style: const TextStyle(fontSize: 11))]),
      );

  Widget _buildSoloMemory() => _soloPanel(child: Column(children: [
        Row(children: [Expanded(child: Text('جفت‌ها: ${_memoryMatched.length ~/ 2} از ۸', style: const TextStyle(fontWeight: FontWeight.w900))), Text('تلاش: $_memoryAttempts', style: TextStyle(color: widget.game.accent, fontWeight: FontWeight.w800))]),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _memoryDeck.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, crossAxisSpacing: 7, mainAxisSpacing: 7),
          itemBuilder: (context, index) {
            final visible = _memoryRevealed.contains(index) || _memoryMatched.contains(index);
            return Material(color: visible ? widget.game.accent.withValues(alpha: .13) : const Color(0xFF182335), borderRadius: BorderRadius.circular(12), child: InkWell(onTap: _busy || _finished || visible ? null : () => _flipSoloMemory(index), borderRadius: BorderRadius.circular(12), child: Center(child: Text(visible ? _memoryDeck[index] : '؟', style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900)))));
          },
        ),
      ]));

  Widget _buildSoloHangman() {
    final display = _hangmanWord.runes.map((rune) {
      final letter = String.fromCharCode(rune);
      return _hangmanGuessed.contains(letter) || _finished ? letter : 'ـ';
    }).join('  ');
    return _soloPanel(child: Column(children: [
      Text(display, style: TextStyle(color: widget.game.accent, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 2)),
      const SizedBox(height: 9),
      Text('خطاها: $_hangmanWrong از ۷', style: const TextStyle(color: Colors.white60, fontSize: 12)),
      const SizedBox(height: 14),
      Wrap(spacing: 5, runSpacing: 6, alignment: WrapAlignment.center, children: [
        for (final letter in _persianLetters)
          SizedBox(width: 40, height: 42, child: FilledButton(
            onPressed: _finished || _hangmanGuessed.contains(letter) ? null : () => _guessSoloHangman(letter),
            style: FilledButton.styleFrom(backgroundColor: _hangmanGuessed.contains(letter) ? Colors.white10 : widget.game.accent.withValues(alpha: .18), foregroundColor: Colors.white, padding: EdgeInsets.zero),
            child: Text(letter, style: const TextStyle(fontWeight: FontWeight.w900)),
          )),
      ]),
    ]));
  }

  Widget _buildSoloMath() {
    if (_mathIndex >= 10) return _soloPanel(child: const Text('آزمون تمام شد.'));
    final question = _mathQuestions[_mathOrder[_mathIndex]];
    return Column(children: [
      _soloPanel(child: Column(children: [Text('سؤال ${_mathIndex + 1} از ۱۰', style: TextStyle(color: widget.game.accent, fontWeight: FontWeight.w900)), const SizedBox(height: 10), Text(question.expression, style: const TextStyle(fontSize: 29, fontWeight: FontWeight.w900))])),
      const SizedBox(height: 12),
      _soloTextInput(hint: 'پاسخ عددی', keyboardType: TextInputType.number, onSend: _submitSoloMath),
      const SizedBox(height: 10),
      FilledButton(onPressed: _finished ? null : _submitSoloMath, child: const Text('ثبت پاسخ')),
    ]);
  }

  Widget _buildSoloWordChain() => _soloPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('واژه‌ها', style: TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [for (var i = 0; i < _chainWords.length; i++) _MiniTag(text: '${i.isEven ? 'تو' : 'حریف'}: ${_chainWords[i]}', color: i.isEven ? widget.game.accent : Colors.pinkAccent)]),
        const SizedBox(height: 12),
        Text('واژه بعدی باید با «${_lastPersianLetter(_chainWords.last)}» شروع شود.', style: TextStyle(color: widget.game.accent, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        _soloTextInput(hint: 'واژه‌ات را وارد کن', onSend: _submitSoloWordChain),
        const SizedBox(height: 10),
        FilledButton(onPressed: _finished ? null : _submitSoloWordChain, child: const Text('ثبت واژه')),
      ]));

  Widget _buildSoloNumber() => Column(children: [
        _soloPanel(child: Column(children: [
          const Text('یک عدد بین ۱ تا ۵۰ پیدا کن', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 8),
          Text('تلاش $_numberAttempts از ۷', style: TextStyle(color: widget.game.accent, fontWeight: FontWeight.w900)),
          if (_numberHint.isNotEmpty) ...[const SizedBox(height: 8), Text(_numberHint, style: const TextStyle(fontWeight: FontWeight.w800))],
        ])),
        const SizedBox(height: 12),
        _soloTextInput(hint: 'عدد ۱ تا ۵۰', keyboardType: TextInputType.number, onSend: _submitSoloNumberGuess),
        const SizedBox(height: 10),
        FilledButton(onPressed: _finished ? null : _submitSoloNumberGuess, child: const Text('حدس بزن')),
      ]);

  Widget _buildSoloMines() => _soloPanel(child: Column(children: [
        Row(children: [Expanded(child: Text('خانه‌های امن: ${_mineRevealed.length} از ۲۰', style: const TextStyle(fontWeight: FontWeight.w900))), Text('۵ مین', style: TextStyle(color: widget.game.accent, fontWeight: FontWeight.w800))]),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 25,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5, crossAxisSpacing: 7, mainAxisSpacing: 7),
          itemBuilder: (context, index) {
            final mine = _mines.contains(index);
            final open = _mineRevealed.contains(index) || (_finished && mine);
            return Material(
              color: index == _explodedMine ? Colors.redAccent.withValues(alpha: .25) : (open ? (mine ? Colors.redAccent.withValues(alpha: .2) : Colors.greenAccent.withValues(alpha: .12)) : const Color(0xFF182335)),
              borderRadius: BorderRadius.circular(11),
              child: InkWell(onTap: open || _finished ? null : () => _tapSoloMine(index), borderRadius: BorderRadius.circular(11), child: Center(child: Text(open ? (mine ? '💣' : '✓') : '·', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)))),
            );
          },
        ),
      ]));

  Widget _buildSoloNameFamily() => Column(children: [
        _soloPanel(child: Row(children: [
          Container(width: 54, height: 54, alignment: Alignment.center, decoration: BoxDecoration(color: widget.game.accent.withValues(alpha: .14), borderRadius: BorderRadius.circular(16)), child: Text(_familyLetter, style: TextStyle(fontSize: 31, color: widget.game.accent, fontWeight: FontWeight.w900))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('دور $_round از ۵', style: const TextStyle(fontWeight: FontWeight.w900)), const SizedBox(height: 3), const Text('۶۰ ثانیه فرصت داری', style: TextStyle(color: Colors.white60, fontSize: 11))])),
          Text('$_familySeconds ثانیه', style: TextStyle(color: _familySeconds <= 10 ? Colors.redAccent : widget.game.accent, fontWeight: FontWeight.w900)),
        ])),
        const SizedBox(height: 10),
        _soloPanel(child: Column(children: [
          for (final category in _nameFamilyCategories) ...[
            TextField(controller: _familyControllers[category], enabled: !_familyScored && !_finished, decoration: InputDecoration(labelText: category, hintText: 'با حرف $_familyLetter'), textDirection: TextDirection.rtl),
            const SizedBox(height: 7),
          ],
          if (!_familyScored && !_finished) FilledButton.icon(onPressed: _submitSoloNameFamily, icon: const Icon(Icons.calculate_rounded), label: const Text('ثبت و محاسبه خودکار امتیاز')),
          if (_familyScored) ...[
            const Divider(height: 20),
            const Text('امتیاز هر دسته', style: TextStyle(fontWeight: FontWeight.w900)),
            for (final category in _nameFamilyCategories) ListTile(dense: true, contentPadding: EdgeInsets.zero, title: Text(category), trailing: Text('${_familyBreakdown[category] ?? 0} امتیاز', style: TextStyle(color: widget.game.accent, fontWeight: FontWeight.w900))),
            const Divider(height: 22),
            const Text('رقابت با دو ربات', style: TextStyle(fontWeight: FontWeight.w900)),
            for (final botName in ['ربات اول', 'ربات دوم']) ...[
              const SizedBox(height: 8),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text('$botName · ${_familyBotTotals[botName] ?? 0} امتیاز', style: TextStyle(color: widget.game.accent, fontWeight: FontWeight.w800)),
                children: [
                  for (final category in _nameFamilyCategories)
                    ListTile(dense: true, title: Text(category), subtitle: Text(_familyBotAnswers[botName]?[category] ?? '—'), trailing: Text('${_familyBotBreakdowns[botName]?[category] ?? 0}')),
                ],
              ),
            ],
            Text('قانون: پاسخ با حرف درست و غیرتکراری ۱۰ امتیاز؛ پاسخ تکراری ۵؛ خالی یا با حرف اشتباه صفر.', style: const TextStyle(color: Colors.white54, fontSize: 10, height: 1.6)),
            if (!_finished) FilledButton.icon(onPressed: _nextSoloNameFamilyRound, icon: const Icon(Icons.skip_next_rounded), label: const Text('حرف بعدی')),
          ],
        ])),
      ]);
}


class _ScoreBoard extends StatelessWidget {
  const _ScoreBoard({required this.myName, required this.otherName, required this.myScore, required this.otherScore, required this.myColor});
  final String myName;
  final String otherName;
  final int myScore;
  final int otherScore;
  final Color myColor;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(child: _PlayerScore(name: myName, score: myScore, color: myColor, isMe: true)),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('VS', style: TextStyle(color: Colors.white38, fontWeight: FontWeight.w900, fontSize: 11))),
          Expanded(child: _PlayerScore(name: otherName, score: otherScore, color: const Color(0xFFFF76A7), isMe: false)),
        ],
      );
}

class _PlayerScore extends StatelessWidget {
  const _PlayerScore({required this.name, required this.score, required this.color, required this.isMe});
  final String name;
  final int score;
  final Color color;
  final bool isMe;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 12),
        decoration: BoxDecoration(color: color.withValues(alpha: .09), borderRadius: BorderRadius.circular(18), border: Border.all(color: color.withValues(alpha: .24))),
        child: Row(
          children: [
            Icon(isMe ? Icons.person_rounded : Icons.favorite_rounded, color: color, size: 18),
            const SizedBox(width: 7),
            Expanded(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
            Text('$score', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: color)),
          ],
        ),
      );
}

class _TinyScore extends StatelessWidget {
  const _TinyScore({required this.label, required this.score, required this.color});
  final String label;
  final int score;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: color.withValues(alpha: .09), borderRadius: BorderRadius.circular(20)),
        child: Text('$label  $score', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900)),
      );
}

class _ConnectionPill extends StatelessWidget {
  const _ConnectionPill({required this.online});
  final bool online;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: BoxDecoration(color: (online ? Colors.greenAccent : Colors.orangeAccent).withValues(alpha: .1), borderRadius: BorderRadius.circular(30), border: Border.all(color: (online ? Colors.greenAccent : Colors.orangeAccent).withValues(alpha: .2))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: online ? Colors.greenAccent : Colors.orangeAccent)),
          const SizedBox(width: 6),
          Text(online ? 'زنده' : 'قطع', style: TextStyle(fontSize: 10, color: online ? Colors.greenAccent : Colors.orangeAccent, fontWeight: FontWeight.w900)),
        ]),
      );
}

class _MiniTag extends StatelessWidget {
  const _MiniTag({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: color.withValues(alpha: .1), borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w800)),
      );
}

class _Riddle {
  const _Riddle(this.question, this.answers);
  final String question;
  final List<String> answers;
}

class _MathQuestion {
  const _MathQuestion(this.expression, this.answer);
  final String expression;
  final int answer;
}

String _botFamilyAnswer(String category, String letter, int botIndex) {
  const bank = <String, Map<String, List<String>>>{
    'اسم': {'ا':['آرمان','آوا'], 'ب':['بهار','باران'], 'پ':['پارسا','پریسا'], 'ت':['ترانه','تیام'], 'ج':['جواد','جانان'], 'د':['داریوش','دریا'], 'ر':['رضا','رها'], 'س':['سارا','سام'], 'ش':['شایان','شیدا'], 'ف':['فرهاد','فرزانه'], 'ک':['کامران','کیانا'], 'گ':['گلناز','گرشا'], 'م':['مریم','مانی'], 'ن':['نیما','نگار']},
    'فامیل': {'ا':['احمدی','امیری'], 'ب':['بهشتی','بابایی'], 'پ':['پارسا','پورمحمدی'], 'ت':['توکلی','تهرانی'], 'ج':['جعفری','جهانگیری'], 'د':['داوری','دلاوری'], 'ر':['رضایی','رحیمی'], 'س':['سلیمانی','سعیدی'], 'ش':['شریفی','شاکری'], 'ف':['فرهمند','فلاحی'], 'ک':['کریمی','کاظمی'], 'گ':['گودرزی','گلستانی'], 'م':['محمدی','موسوی'], 'ن':['نوری','نجفی']},
    'شهر': {'ا':['اصفهان','اراک'], 'ب':['بوشهر','بابل'], 'پ':['پارس‌آباد','پاکدشت'], 'ت':['تهران','تبریز'], 'ج':['جیرفت','جهرم'], 'د':['دزفول','دامغان'], 'ر':['رشت','رفسنجان'], 'س':['ساری','سنندج'], 'ش':['شیراز','شاهرود'], 'ف':['فومن','فردوس'], 'ک':['کرمان','کاشان'], 'گ':['گرگان','گنبدکاووس'], 'م':['مشهد','ملایر'], 'ن':['نیشابور','نور']},
    'کشور': {'ا':['ایران','ایتالیا'], 'ب':['برزیل','بلژیک'], 'پ':['پاکستان','پرتغال'], 'ت':['ترکیه','تایلند'], 'ج':['جیبوتی','جامائیکا'], 'د':['دانمارک','دومینیکن'], 'ر':['روسیه','رومانی'], 'س':['سوئد','سوئیس'], 'ش':['شیلی','شمال مقدونیه'], 'ف':['فرانسه','فنلاند'], 'ک':['کانادا','کوبا'], 'گ':['گرجستان','گابن'], 'م':['مصر','مکزیک'], 'ن':['نروژ','نیجریه']},
    'میوه': {'ا':['انار','انبه'], 'ب':['به','بلوبری'], 'پ':['پرتقال','پاپایا'], 'ت':['توت','تمر هندی'], 'ج':['گیلاس','جک‌فروت'], 'د':['دراگون‌فروت','دوریان'], 'ر':['رامبوتان','رزبری'], 'س':['سیب','سنجد'], 'ش':['شلیل','شاه‌توت'], 'ف':['فیسالیس','فندق'], 'ک':['کیوی','کامکوات'], 'گ':['گلابی','گریپ‌فروت'], 'م':['موز','ملون'], 'ن':['نارنگی','نارگیل']},
    'غذا': {'ا':['آش','املت'], 'ب':['باقالی‌پلو','برگر'], 'پ':['پیتزا','پلو'], 'ت':['ته‌چین','تاس‌کباب'], 'ج':['جوجه‌کباب','جوپلو'], 'د':['دلمه','دیزی'], 'ر':['رشته‌پلو','رولت'], 'س':['سبزی‌پلو','سمبوسه'], 'ش':['شله‌زرد','شامی'], 'ف':['فلافل','فسنجان'], 'ک':['کباب','کوکو'], 'گ':['گمنه','گوجه‌پلو'], 'م':['ماکارونی','میرزاقاسمی'], 'ن':['نرگسی','نان‌وپنیر']},
    'اشیا': {'ا':['آینه','انبردست'], 'ب':['بشقاب','بطری'], 'پ':['پنجره','پتو'], 'ت':['تلفن','تخته'], 'ج':['جارو','جعبه'], 'د':['دفتر','دستبند'], 'ر':['رادیو','رنده'], 'س':['ساعت','سینی'], 'ش':['شانه','شمع'], 'ف':['فنجان','فرش'], 'ک':['کتاب','کمد'], 'گ':['گلدان','گیره'], 'م':['میز','مداد'], 'ن':['نردبان','نخ']},
  };
  final options = bank[category]?[letter];
  return options == null || options.isEmpty ? '' : options[botIndex % options.length];
}

const _nameFamilyCategories = <String>['اسم', 'فامیل', 'شهر', 'کشور', 'میوه', 'غذا', 'اشیا'];
const _nameFamilyLetters = <String>['ا', 'ب', 'پ', 'ت', 'ج', 'د', 'ر', 'س', 'ش', 'ف', 'ک', 'گ', 'م', 'ن'];
const _soloWordPool = <String>[
  'کتاب', 'باران', 'نبات', 'توت', 'تلفن', 'نمک', 'کبوتر', 'رودخانه', 'هواپیما',
  'مداد', 'دریا', 'آسمان', 'نارنج', 'جنگل', 'لامپ', 'پروانه', 'هندوانه', 'انار',
  'رادیو', 'وطن', 'نقاشی', 'یاس', 'ستاره', 'هلو', 'پنجره', 'هیزم', 'مادر', 'رنگ',
  'گل', 'لباس', 'ساعت', 'تاریخ', 'خواب', 'باغ', 'غذا', 'آینه', 'هفت', 'فنجان',
  'نردبان', 'بار', 'راه', 'هوا', 'یخ', 'خنده', 'هدهد', 'دست', 'تخم', 'موز',
];

const _memorySymbols = <String>['🍎', '🚀', '🐳', '⭐', '🎲', '🌈', '🦋', '🎧'];

const _hangmanWords = <String>[
  'کتاب', 'باران', 'دریا', 'آسمان', 'پروانه', 'دوچرخه', 'ستاره', 'آینه',
  'جنگل', 'پرنده', 'خورشید', 'پنجره', 'مداد', 'گلابی', 'کبوتر', 'رنگینکمان',
];

const _persianLetters = <String>[
  'ا', 'ب', 'پ', 'ت', 'ث', 'ج', 'چ', 'ح', 'خ', 'د', 'ذ', 'ر', 'ز', 'ژ',
  'س', 'ش', 'ص', 'ض', 'ط', 'ظ', 'ع', 'غ', 'ف', 'ق', 'ک', 'گ', 'ل', 'م',
  'ن', 'و', 'ه', 'ی',
];

const _mathQuestions = <_MathQuestion>[
  _MathQuestion('۸ + ۷ = ؟', 15),
  _MathQuestion('۱۲ − ۵ = ؟', 7),
  _MathQuestion('۶ × ۴ = ؟', 24),
  _MathQuestion('۳۶ ÷ ۶ = ؟', 6),
  _MathQuestion('۹ + ۸ = ؟', 17),
  _MathQuestion('۲۰ − ۱۳ = ؟', 7),
  _MathQuestion('۷ × ۵ = ؟', 35),
  _MathQuestion('۸۱ ÷ ۹ = ؟', 9),
  _MathQuestion('۱۴ + ۱۹ = ؟', 33),
  _MathQuestion('۵۰ − ۲۶ = ؟', 24),
  _MathQuestion('۸ × ۸ = ؟', 64),
  _MathQuestion('۱۰۰ ÷ ۱۰ = ؟', 10),
];

const _wordSeeds = <String>['کتاب', 'باران', 'دریا', 'مداد', 'پنجره', 'ستاره'];

String _normalizeWord(String input) => _normalizeAnswer(input).replaceAll(RegExp(r'[^آ-ی]'), '');

int? _parseDigits(String input) {
  final normalized = String.fromCharCodes(input.runes.map((rune) {
    if (rune >= 0x06F0 && rune <= 0x06F9) return rune - 0x06F0 + 0x30;
    if (rune >= 0x0660 && rune <= 0x0669) return rune - 0x0660 + 0x30;
    return rune;
  }));
  return int.tryParse(normalized.trim().replaceAll(',', '').replaceAll('٬', ''));
}

String _lastPersianLetter(String word) {
  final normalized = _normalizeWord(word);
  if (normalized.isEmpty) return '';
  return String.fromCharCode(normalized.runes.last);
}

const _riddles = <_Riddle>[
  _Riddle('آن چیست که هرچه بیشتر از آن برداری، بزرگ‌تر می‌شود؟', ['چاله', 'گودال']),
  _Riddle('چه چیزی کلید دارد اما هیچ قفلی را باز نمی‌کند؟', ['پیانو', 'کیبورد', 'صفحه کلید']),
  _Riddle('هرچه بیشتر خشک می‌کند، خودش خیس‌تر می‌شود؛ چیست؟', ['حوله']),
  _Riddle('مال توست، اما دیگران بیشتر از خودت از آن استفاده می‌کنند؛ چیست؟', ['نام', 'اسمت', 'اسم']),
  _Riddle('چه چیزی سوراخ‌های زیادی دارد اما می‌تواند آب را نگه دارد؟', ['اسفنج']),
  _Riddle('چه چیزی چشم دارد ولی نمی‌تواند ببیند؟', ['سوزن']),
  _Riddle('همیشه بالا می‌رود و هیچ‌وقت پایین نمی‌آید؛ چیست؟', ['سن', 'عمر']),
  _Riddle('چه چیزی دور دنیا می‌گردد اما همیشه در یک گوشه می‌ماند؟', ['تمبر']),
  _Riddle('چه چیزی دندان دارد اما غذا نمی‌خورد؟', ['شانه']),
  _Riddle('چه چیزی هرقدر از آن استفاده کنی، کوتاه‌تر می‌شود؟', ['مداد', 'شمع']),
];

int _asInt(dynamic value) => value is int ? value : int.tryParse(value?.toString() ?? '') ?? 0;

Map<String, int> _readScores(dynamic raw) {
  final map = raw is Map ? raw : const {};
  return {
    'me': _asInt(map['me']),
    'sister': _asInt(map['sister']),
  };
}

String? _findWinner(List<String?> board, List<List<int>> lines) {
  for (final line in lines) {
    final first = board[line[0]];
    if (first != null && first == board[line[1]] && first == board[line[2]]) return first;
  }
  return null;
}

String _normalizeAnswer(String input) {
  var value = input.trim().toLowerCase();
  const replacements = {
    'ي': 'ی', 'ى': 'ی', 'ك': 'ک', 'أ': 'ا', 'إ': 'ا', 'آ': 'ا', 'ة': 'ه',
  };
  for (final entry in replacements.entries) {
    value = value.replaceAll(entry.key, entry.value);
  }
  return value.replaceAll(RegExp(r'[\s\u200c،,.!؟?؛:ـ_\-]+'), '');
}

String _friendlyError(Object error) {
  final value = error.toString().replaceFirst('Bad state: ', '');
  if (value.contains('not_authenticated')) return 'ابتدا وارد حساب خصوصی خود شوید.';
  if (value.contains('SocketException') || value.contains('connection')) return 'اتصال اینترنت یا سرور در دسترس نیست.';
  return 'همگام‌سازی بازی انجام نشد. اتصال سرور را بررسی و دوباره تلاش کن.';
}

String _gameTitle(String? id) => _games.where((g) => g.id == id).map((g) => g.title).firstOrNull ?? 'بازی قبلی';

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
