import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ocr_notes_app/controllers/note_controller.dart';
import 'package:ocr_notes_app/models/note.dart';

// ─── Entry Point ─────────────────────────────────────────────────────────────
void main() {
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const OcrNotesApp());
}

// ─── App Root ─────────────────────────────────────────────────────────────────
class OcrNotesApp extends StatelessWidget {
  const OcrNotesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '我的筆記',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      home: const HomeScreen(),
    );
  }

  ThemeData _buildTheme() {
    const bg = Color(0xFF1A1A2E);
    const surface = Color(0xFF16213E);
    const surface2 = Color(0xFF0F3460);
    const accent = Color(0xFF7B61FF);
    const accentLight = Color(0xFF9B85FF);
    const textPrimary = Color(0xFFFFFFFF);
    const textMuted = Color(0xFFAAAAAA);

    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bg,
      colorScheme: const ColorScheme.dark(
        background: bg,
        surface: surface,
        primary: accent,
        onPrimary: textPrimary,
        onBackground: textPrimary,
        onSurface: textPrimary,
      ),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: textPrimary, fontFamily: 'sans-serif'),
        bodySmall: TextStyle(color: textMuted),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: bg,
        elevation: 0,
        iconTheme: IconThemeData(color: textPrimary),
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        hintStyle: const TextStyle(color: textMuted),
      ),
    );
  }
}

// ─── App Colors ───────────────────────────────────────────────────────────────
class AppColors {
  static const bg = Color(0xFF1A1A2E);
  static const surface = Color(0xFF1E1E35);
  static const surface2 = Color(0xFF252540);
  static const card = Color(0xFF22223A);
  static const accent = Color(0xFF7B61FF);
  static const accentDim = Color(0xFF4A3FA0);
  static const accentLight = Color(0xFF9B85FF);
  static const textPrimary = Color(0xFFFFFFFF);
  static const textMuted = Color(0xFFAAAAAA);
  static const textFaint = Color(0xFF666680);
  static const tagMath = Color(0xFF7B61FF);
  static const tagEnglish = Color(0xFF3A7BFF);
  static const tagPhysics = Color(0xFF2FB8A0);
  static const tagHistory = Color(0xFFFF6B6B);
}

Color tagColor(String tag) {
  switch (tag) {
    case '數學': return AppColors.tagMath;
    case '英文': return AppColors.tagEnglish;
    case '物理': return AppColors.tagPhysics;
    case '歷史': return AppColors.tagHistory;
    default: return AppColors.accent;
  }
}

String formatDate(DateTime dt) =>
    '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';

// ═══════════════════════════════════════════════════════════════════════════════
// ① HOME SCREEN
// ═══════════════════════════════════════════════════════════════════════════════
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isGridView = false;
  final TextEditingController _searchCtrl = TextEditingController();
  final NoteController _controller = NoteController();
  List<Note> _notes = [];
  List<Note> _filteredNotes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    setState(() => _loading = true);
    try {
      final notes = await _controller.getAllNotes();
      setState(() {
        _notes = notes;
        _filteredNotes = List.from(_notes);
      });
    } catch (e) {
      // Ignoring errors for now; could surface a message
    } finally {
      setState(() => _loading = false);
    }
  }

  void _onSearch(String q) {
    setState(() {
      final query = q.trim();
      if (query.isEmpty) {
        _filteredNotes = List.from(_notes);
      } else {
        _filteredNotes = _notes
            .where((n) =>
                n.title.contains(query) ||
                n.content.contains(query) ||
                n.tags.any((t) => t.contains(query)))
            .toList();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildSearchBar(),
            _buildSectionTitle(),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _isGridView
                      ? _buildGridView()
                      : _buildListView(),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildFAB(context),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            '我的筆記',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.accent,
            child: const Text(
              '王',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: TextField(
        controller: _searchCtrl,
        onChanged: _onSearch,
        style: const TextStyle(color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: '搜尋筆記、標籤...',
          hintStyle: const TextStyle(color: AppColors.textFaint),
          prefixIcon: const Icon(Icons.search, color: AppColors.textFaint),
          filled: true,
          fillColor: AppColors.surface2,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildSectionTitle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '最近 ${_filteredNotes.length} 則筆記',
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 13,
            ),
          ),
          Row(
            children: [
              _viewToggleBtn(Icons.grid_view_rounded, true),
              const SizedBox(width: 4),
              _viewToggleBtn(Icons.view_list_rounded, false),
            ],
          ),
        ],
      ),
    );
  }

  Widget _viewToggleBtn(IconData icon, bool isGrid) {
    final active = _isGridView == isGrid;
    return GestureDetector(
      onTap: () => setState(() => _isGridView = isGrid),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: active ? AppColors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon,
            size: 18,
            color: active ? Colors.white : AppColors.textMuted),
      ),
    );
  }

  Widget _buildListView() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      itemCount: _filteredNotes.length,
      itemBuilder: (ctx, i) => _NoteListTile(
        note: _filteredNotes[i],
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => EditNoteScreen(note: _filteredNotes[i])),
          ).then((_) => _loadNotes());
        },
      ),
    );
  }

  Widget _buildGridView() {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _filteredNotes.length,
      itemBuilder: (ctx, i) => _NoteGridCard(
        note: _filteredNotes[i],
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => EditNoteScreen(note: _filteredNotes[i])),
          ).then((_) => _loadNotes());
        },
      ),
    );
  }

  Widget _buildFAB(BuildContext context) {
    return FloatingActionButton(
      backgroundColor: AppColors.accent,
      onPressed: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: AppColors.surface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (_) => _CaptureBottomSheet(parentContext: context),
        ).whenComplete(() => _loadNotes());
      },
      child: const Icon(Icons.camera_alt_rounded, color: Colors.white),
    );
  }
}

class _NoteListTile extends StatelessWidget {
  final Note note;
  final VoidCallback onTap;
  const _NoteListTile({required this.note, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    note.title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatDate(note.createdAt),
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (note.tags.isNotEmpty)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: tagColor(note.tags.first).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  note.tags.first,
                  style: TextStyle(
                    color: tagColor(note.tags.first),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NoteGridCard extends StatelessWidget {
  final Note note;
  final VoidCallback onTap;
  const _NoteGridCard({required this.note, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (note.tags.isNotEmpty)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: tagColor(note.tags.first).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  note.tags.first,
                  style: TextStyle(
                    color: tagColor(note.tags.first),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Text(
              note.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              formatDate(note.createdAt),
              style: const TextStyle(color: AppColors.textFaint, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Bottom Sheet: Choose capture mode ────────────────────────────────────────
class _CaptureBottomSheet extends StatelessWidget {
  final BuildContext parentContext;
  const _CaptureBottomSheet({required this.parentContext});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textFaint,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '新增筆記',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          _sheetOption(
            icon: Icons.camera_alt_rounded,
            label: '相機拍攝',
            subtitle: '開啟相機立即拍攝',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                parentContext,
                MaterialPageRoute(builder: (_) => const CameraScreen()),
              );
            },
          ),
          const SizedBox(height: 12),
          _sheetOption(
            icon: Icons.photo_library_rounded,
            label: '從相簿選取',
            subtitle: '從相簿選取單張或多張',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                parentContext,
                MaterialPageRoute(builder: (_) => const GalleryPickerScreen()),
              );
            },
          ),
          const SizedBox(height: 12),
          _sheetOption(
            icon: Icons.edit_note_rounded,
            label: '手動建立',
            subtitle: '直接輸入文字建立筆記',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                parentContext,
                MaterialPageRoute(builder: (_) => const EditNoteScreen()),
              );
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _sheetOption({
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.accent, size: 22),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600)),
                Text(subtitle,
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 12)),
              ],
            ),
            const Spacer(),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textFaint),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ② CAMERA SCREEN
// ═══════════════════════════════════════════════════════════════════════════════
class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _scanAnim;
  late Animation<double> _scanPos;

  @override
  void initState() {
    super.initState();
    _scanAnim = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _scanPos = Tween(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _scanAnim, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _scanAnim.dispose();
    super.dispose();
  }

  void _onCapture() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const OcrProgressScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera preview placeholder
          Container(color: const Color(0xFF0D0D1A)),

          // Grid overlay
          CustomPaint(
            size: MediaQuery.of(context).size,
            painter: _GridPainter(),
          ),

          // Document frame
          Center(
            child: _DocumentFrame(scanPos: _scanPos),
          ),

          // Top bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    '相機',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),
          ),

          // Bottom hint
          Positioned(
            bottom: 120,
            left: 0,
            right: 0,
            child: Column(
              children: [
                const Text(
                  '對齊文件邊框',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 6),
                Text(
                  '閃光燈：自動  ｜  解析度：高',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.4), fontSize: 12),
                ),
              ],
            ),
          ),

          // Bottom controls
          Positioned(
            bottom: 32,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _camBtn(Icons.star_outline_rounded, () {}),
                _shutterBtn(),
                _camBtn(Icons.crop_square_rounded, () {}),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _camBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }

  Widget _shutterBtn() {
    return GestureDetector(
      onTap: _onCapture,
      child: Container(
        width: 72,
        height: 72,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Container(
            width: 60,
            height: 60,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

class _DocumentFrame extends StatelessWidget {
  final Animation<double> scanPos;
  const _DocumentFrame({required this.scanPos});

  @override
  Widget build(BuildContext context) {
    const frameW = 260.0;
    const frameH = 340.0;
    return SizedBox(
      width: frameW,
      height: frameH,
      child: Stack(
        children: [
          // Corner borders
          CustomPaint(
            size: const Size(frameW, frameH),
            painter: _CornerPainter(),
          ),
          // Scan line
          AnimatedBuilder(
            animation: scanPos,
            builder: (_, __) => Positioned(
              top: scanPos.value * (frameH - 4),
              left: 0,
              right: 0,
              child: Container(
                height: 2,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    Colors.transparent,
                    AppColors.accent.withOpacity(0.8),
                    Colors.transparent,
                  ]),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.accent
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const len = 28.0;
    final paths = [
      // TL
      [Offset(0, len), const Offset(0, 0), Offset(len, 0)],
      // TR
      [Offset(size.width - len, 0), Offset(size.width, 0), Offset(size.width, len)],
      // BL
      [Offset(0, size.height - len), Offset(0, size.height), Offset(len, size.height)],
      // BR
      [Offset(size.width - len, size.height), Offset(size.width, size.height), Offset(size.width, size.height - len)],
    ];

    for (final pts in paths) {
      final path = Path()
        ..moveTo(pts[0].dx, pts[0].dy)
        ..lineTo(pts[1].dx, pts[1].dy)
        ..lineTo(pts[2].dx, pts[2].dy);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..strokeWidth = 0.5;
    const step = 32.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ═══════════════════════════════════════════════════════════════════════════════
// ③ OCR PROGRESS SCREEN
// ═══════════════════════════════════════════════════════════════════════════════
class OcrProgressScreen extends StatefulWidget {
  const OcrProgressScreen({super.key});

  @override
  State<OcrProgressScreen> createState() => _OcrProgressScreenState();
}

class _OcrProgressScreenState extends State<OcrProgressScreen>
    with TickerProviderStateMixin {
  double _progress = 0.0;
  int _seconds = 3;
  late AnimationController _circleAnim;

  @override
  void initState() {
    super.initState();
    _circleAnim = AnimationController(vsync: this, duration: const Duration(seconds: 4));
    _startProgress();
  }

  void _startProgress() async {
    for (int i = 1; i <= 100; i++) {
      await Future.delayed(const Duration(milliseconds: 35));
      if (!mounted) return;
      setState(() {
        _progress = i / 100;
        _seconds = ((100 - i) * 0.035).ceil().clamp(0, 9);
      });
      _circleAnim.animateTo(_progress);
    }
    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 400));
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const EditNoteScreen()),
    );
  }

  @override
  void dispose() {
    _circleAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pct = (_progress * 100).round();
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        leading: const SizedBox(),
        title: const Text('辨識中'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 24),
              // Image preview placeholder
              Container(
                width: double.infinity,
                height: 180,
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Stack(
                  children: [
                    // Simulated text lines
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: List.generate(
                          5,
                          (i) => Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            height: 10,
                            width: i == 4 ? 120 : double.infinity,
                            decoration: BoxDecoration(
                              color: AppColors.textFaint.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Scan progress overlay
                    Positioned(
                      top: _progress * 155,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 2,
                        color: AppColors.accent.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // Circle progress
              SizedBox(
                width: 120,
                height: 120,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: _progress,
                      strokeWidth: 8,
                      backgroundColor: AppColors.surface2,
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(AppColors.accent),
                    ),
                    Text(
                      '$pct%',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),
              const Text(
                'OCR 辨識處理中',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '正在分析文字內容',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
              Text(
                '預估剩餘時間：約 $_seconds 秒',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),

              const SizedBox(height: 24),

              // Linear progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _progress,
                  backgroundColor: AppColors.surface2,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppColors.accent),
                  minHeight: 6,
                ),
              ),

              const Spacer(),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  '取消並重新拍攝',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ④ GALLERY PICKER SCREEN
// ═══════════════════════════════════════════════════════════════════════════════
class GalleryPickerScreen extends StatefulWidget {
  const GalleryPickerScreen({super.key});

  @override
  State<GalleryPickerScreen> createState() => _GalleryPickerScreenState();
}

class _GalleryPickerScreenState extends State<GalleryPickerScreen> {
  final Set<int> _selected = {};
  int _tabIndex = 0;
  final List<String> _tabs = ['最近項目', '文件', '截圖'];

  // Placeholder colors for mock images
  final List<Color> _mockColors = [
    const Color(0xFFB5B8FF),
    const Color(0xFFB5E8C0),
    const Color(0xFFFFD6B5),
    const Color(0xFFB5D8FF),
    const Color(0xFFFFB5D6),
    const Color(0xFFD6FFB5),
    const Color(0xFFFFFFB5),
    const Color(0xFFB5FFFF),
    const Color(0xFFFFB5FF),
  ];

  void _onImport() {
    if (_selected.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const OcrProgressScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('< 返回',
              style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
        ),
        leadingWidth: 80,
        title: const Text('選取照片'),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () => setState(() {
              if (_selected.length == _mockColors.length) {
                _selected.clear();
              } else {
                _selected.addAll(
                    List.generate(_mockColors.length, (i) => i));
              }
            }),
            child: Text(
              _selected.length == _mockColors.length ? '取消全選' : '全選',
              style: const TextStyle(color: AppColors.textMuted),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Tab bar
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: List.generate(
                _tabs.length,
                (i) => GestureDetector(
                  onTap: () => setState(() => _tabIndex = i),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 7),
                    decoration: BoxDecoration(
                      color: _tabIndex == i
                          ? AppColors.accent
                          : AppColors.surface2,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _tabs[i],
                      style: TextStyle(
                        color: _tabIndex == i
                            ? Colors.white
                            : AppColors.textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Grid
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
              ),
              itemCount: _mockColors.length,
              itemBuilder: (ctx, i) {
                final selected = _selected.contains(i);
                return GestureDetector(
                  onTap: () => setState(() {
                    if (selected) {
                      _selected.remove(i);
                    } else {
                      _selected.add(i);
                    }
                  }),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Mock image
                        Container(
                          color: _mockColors[i],
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: List.generate(
                                4,
                                (j) => Container(
                                  margin:
                                      const EdgeInsets.only(bottom: 6),
                                  height: 6,
                                  width: j == 3
                                      ? 40
                                      : double.infinity,
                                  color: Colors.black.withOpacity(0.12),
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Overlay on selected
                        if (selected)
                          Container(
                            color: AppColors.accent.withOpacity(0.3),
                          ),
                        // Selection indicator
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.accent
                                  : Colors.white.withOpacity(0.3),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: Colors.white, width: 2),
                            ),
                            child: selected
                                ? const Icon(Icons.check,
                                    size: 14, color: Colors.white)
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Row(
            children: [
              Text(
                _selected.isEmpty
                    ? '尚未選取'
                    : '已選 ${_selected.length} 張',
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 13),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: _selected.isEmpty ? null : _onImport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selected.isEmpty
                      ? AppColors.surface2
                      : AppColors.accent,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 28, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  '匯入辨識',
                  style: TextStyle(
                    color: _selected.isEmpty
                        ? AppColors.textFaint
                        : Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ⑤ EDIT NOTE SCREEN (Rich Text)
// ═══════════════════════════════════════════════════════════════════════════════
class EditNoteScreen extends StatefulWidget {
  final Note? note;
  const EditNoteScreen({super.key, this.note});

  @override
  State<EditNoteScreen> createState() => _EditNoteScreenState();
}

class _EditNoteScreenState extends State<EditNoteScreen> {
  late TextEditingController _titleCtrl;
  late TextEditingController _contentCtrl;
  List<String> _tags = [];
  final NoteController _controller = NoteController();
  final List<String> _allTags = ['數學', '英文', '物理', '歷史', '化學', '生物'];

  // Toolbar state
  bool _isBold = false;
  bool _isUnderline = false;
  bool _isItalic = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl =
        TextEditingController(text: widget.note?.title ?? '');
    _contentCtrl =
        TextEditingController(text: widget.note?.content ?? '');
    _tags = List.from(widget.note?.tags ?? []);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _addTag(String tag) {
    if (!_tags.contains(tag)) {
      setState(() => _tags.add(tag));
    }
  }

  void _removeTag(String tag) {
    setState(() => _tags.remove(tag));
  }

  void _showTagPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('選擇標籤',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _allTags
                  .map((t) => GestureDetector(
                        onTap: () {
                          _addTag(t);
                          Navigator.pop(context);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: _tags.contains(t)
                                ? tagColor(t).withOpacity(0.25)
                                : AppColors.surface2,
                            borderRadius: BorderRadius.circular(20),
                            border: _tags.contains(t)
                                ? Border.all(color: tagColor(t))
                                : null,
                          ),
                          child: Text(t,
                              style: TextStyle(
                                color: _tags.contains(t)
                                    ? tagColor(t)
                                    : AppColors.textMuted,
                                fontSize: 13,
                              )),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _onSave() async {
    final title = _titleCtrl.text;
    final content = _contentCtrl.text;
    final rawOcrText = widget.note?.rawOcrText ?? '';
    final imagePath = widget.note?.imagePath ?? '';

    try {
      if (widget.note == null) {
        await _controller.saveNote(
          title: title,
          content: content,
          rawOcrText: rawOcrText,
          imagePath: imagePath,
          tags: _tags,
        );
      } else {
        final updated = widget.note!.copyWith(
          title: title.isEmpty ? widget.note!.title : title,
          content: content,
          rawOcrText: rawOcrText,
          imagePath: imagePath,
          tags: _tags,
        );
        await _controller.updateNote(updated);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('筆記已儲存'),
          backgroundColor: AppColors.accent,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('儲存失敗：$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('< 返回',
              style:
                  TextStyle(color: AppColors.textMuted, fontSize: 14)),
        ),
        leadingWidth: 80,
        title: const Text('編輯筆記'),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton(
              onPressed: _onSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('儲存',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title field
                  TextField(
                    controller: _titleCtrl,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: const InputDecoration(
                      hintText: '筆記標題...',
                      hintStyle: TextStyle(
                          color: AppColors.textFaint, fontSize: 22),
                      border: InputBorder.none,
                      filled: false,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),

                  const SizedBox(height: 12),
                  const Divider(color: AppColors.surface2, height: 1),
                  const SizedBox(height: 12),

                  // Tags section
                  Row(
                    children: [
                      const Text('標籤：',
                          style: TextStyle(
                              color: AppColors.textMuted, fontSize: 13)),
                      const SizedBox(width: 4),
                      Wrap(
                        spacing: 6,
                        children: [
                          ..._tags.map((t) => GestureDetector(
                                onTap: () => _removeTag(t),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color:
                                        tagColor(t).withOpacity(0.2),
                                    borderRadius:
                                        BorderRadius.circular(20),
                                  ),
                                  child: Text(t,
                                      style: TextStyle(
                                          color: tagColor(t),
                                          fontSize: 12)),
                                ),
                              )),
                          GestureDetector(
                            onTap: _showTagPicker,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.surface2,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: AppColors.accent,
                                    style: BorderStyle.solid),
                              ),
                              child: const Text('+ 新增',
                                  style: TextStyle(
                                      color: AppColors.accent,
                                      fontSize: 12)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Content field
                  TextField(
                    controller: _contentCtrl,
                    maxLines: null,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight:
                          _isBold ? FontWeight.bold : FontWeight.normal,
                      fontStyle: _isItalic
                          ? FontStyle.italic
                          : FontStyle.normal,
                      decoration: _isUnderline
                          ? TextDecoration.underline
                          : TextDecoration.none,
                      height: 1.7,
                    ),
                    decoration: const InputDecoration(
                      hintText: '開始輸入或 OCR 辨識結果將顯示在這裡...',
                      hintStyle: TextStyle(
                          color: AppColors.textFaint, fontSize: 14),
                      border: InputBorder.none,
                      filled: false,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Rich text toolbar
          _buildToolbar(),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(
            top: BorderSide(color: AppColors.surface2, width: 1)),
      ),
      child: Row(
        children: [
          _toolBtn('B', _isBold, () => setState(() => _isBold = !_isBold),
              fontWeight: FontWeight.bold),
          _toolBtnIcon(Icons.format_underline, _isUnderline,
              () => setState(() => _isUnderline = !_isUnderline)),
          _toolBtn('I', _isItalic, () => setState(() => _isItalic = !_isItalic),
              fontStyle: FontStyle.italic),
          _toolBtnIcon(Icons.format_list_bulleted, false, () {}),
          _toolBtnIcon(Icons.format_list_numbered, false, () {}),
          const SizedBox(width: 4),
          _toolLabel('H1'),
          _toolLabel('H2'),
          const Spacer(),
          _toolBtnIcon(Icons.image_outlined, false, () {}),
        ],
      ),
    );
  }

  Widget _toolBtn(
    String label,
    bool active,
    VoidCallback onTap, {
    FontWeight fontWeight = FontWeight.normal,
    FontStyle fontStyle = FontStyle.normal,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: active
              ? AppColors.accent.withOpacity(0.25)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color:
                active ? AppColors.accentLight : AppColors.textMuted,
            fontWeight: fontWeight,
            fontStyle: fontStyle,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  Widget _toolBtnIcon(IconData icon, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: active
              ? AppColors.accent.withOpacity(0.25)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        alignment: Alignment.center,
        child: Icon(icon,
            size: 18,
            color: active ? AppColors.accentLight : AppColors.textMuted),
      ),
    );
  }

  Widget _toolLabel(String label) {
    return Container(
      height: 34,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
      ),
      alignment: Alignment.center,
      child: Text(label,
          style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 13,
              fontWeight: FontWeight.w600)),
    );
  }
}
