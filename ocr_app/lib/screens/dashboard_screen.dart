import 'package:flutter/material.dart';
import '../controllers/note_controller.dart';
import '../models/note.dart';
import '../widgets/note_card.dart';
import 'camera_screen.dart';
import 'album_picker_screen.dart';
import 'editor_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final NoteController _controller = NoteController();
  final TextEditingController _searchController = TextEditingController();

  List<Note> _notes = [];
  bool _isGridView = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final notes = await _controller.getAllNotes();
      if (!mounted) return;
      setState(() {
        _notes = notes;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('載入筆記失敗：$e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _searchNotes(String query) async {
    try {
      final notes = await _controller.searchNotes(query);
      if (!mounted) return;
      setState(() => _notes = notes);
    } catch (_) {
      // 搜尋失敗時不打斷 UI
    }
  }

  Future<void> _deleteNote(Note note) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('刪除筆記'),
        content: Text('確定要刪除「${note.title}」嗎？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('刪除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _controller.deleteNote(note);
      _loadNotes();
    }
  }

  void _openNote(Note note) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditorScreen(existingNote: note),
      ),
    ).then((_) => _loadNotes());
  }

  void _showCaptureOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFEDE9FE),
                child: Icon(Icons.camera_alt, color: Color(0xFF6C63FF)),
              ),
              title: const Text('拍攝文件'),
              subtitle: const Text('使用相機直接拍攝'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CameraScreen()),
                ).then((_) => _loadNotes());
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFEDE9FE),
                child: Icon(Icons.photo_library, color: Color(0xFF6C63FF)),
              ),
              title: const Text('從相簿選取'),
              subtitle: const Text('選擇現有照片辨識'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AlbumPickerScreen()),
                ).then((_) => _loadNotes());
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildHeader(),
          _buildToggleRow(),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF6C63FF)))
                : _notes.isEmpty
                    ? _buildEmptyState()
                    : _isGridView
                        ? _buildGridView()
                        : _buildListView(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCaptureOptions,
        backgroundColor: const Color(0xFF6C63FF),
        child: const Icon(Icons.camera_alt, color: Colors.white),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: const Color(0xFF6C63FF),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        left: 16,
        right: 16,
        bottom: 12,
      ),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '我的筆記',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w500),
              ),
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.white24,
                child: Text('王',
                    style: TextStyle(color: Colors.white, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: const Color(0x33FFFFFF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: _searchNotes,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: const InputDecoration(
                hintText: '搜尋筆記、標籤…',
                hintStyle: TextStyle(color: Colors.white60),
                prefixIcon: Icon(Icons.search, color: Colors.white60, size: 20),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleRow() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '共 ${_notes.length} 則筆記',
            style: const TextStyle(fontSize: 12, color: Color(0xFF888888)),
          ),
          Row(
            children: [
              _ViewToggleBtn(
                icon: Icons.grid_view,
                active: _isGridView,
                onTap: () => setState(() => _isGridView = true),
              ),
              const SizedBox(width: 4),
              _ViewToggleBtn(
                icon: Icons.list,
                active: !_isGridView,
                onTap: () => setState(() => _isGridView = false),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGridView() {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.1,
      ),
      itemCount: _notes.length,
      itemBuilder: (_, i) => _GridNoteCard(
        note: _notes[i],
        onTap: () => _openNote(_notes[i]),
        onDelete: () => _deleteNote(_notes[i]),
      ),
    );
  }

  Widget _buildListView() {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _notes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => NoteCard(
        note: _notes[i],
        onTap: () => _openNote(_notes[i]),
        onDelete: () => _deleteNote(_notes[i]),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.note_add_outlined, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text('還沒有筆記',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade400)),
          const SizedBox(height: 8),
          Text('點擊右下角按鈕開始掃描',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _searchController.dispose();
    super.dispose();
  }
}

class _ViewToggleBtn extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _ViewToggleBtn(
      {required this.icon, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 26,
        decoration: BoxDecoration(
          color: active ? const Color(0xFF6C63FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Icon(icon, size: 16, color: active ? Colors.white : Colors.grey),
      ),
    );
  }
}

class _GridNoteCard extends StatelessWidget {
  final Note note;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _GridNoteCard(
      {required this.note, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFF9F8FF),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0x14000000), width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Icon(Icons.description_outlined,
                    size: 20, color: Color(0xFF6C63FF)),
                GestureDetector(
                  onTap: onDelete,
                  child: const Icon(Icons.delete_outline,
                      size: 16, color: Color(0xFFAAAAAA)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              note.title,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            Text(
              '${note.updatedAt.month}/${note.updatedAt.day}',
              style: const TextStyle(fontSize: 10, color: Color(0xFFAAAAAA)),
            ),
            if (note.tags.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDE9FE),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  note.tags.first,
                  style: const TextStyle(fontSize: 9, color: Color(0xFF5B21B6)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
