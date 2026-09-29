import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';
import '../theme/miui_theme.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/swipe_back_route.dart';

/// Whether the current signed-in user is the blog admin.
bool get _isAdmin => AuthService().isAdmin;

class BlogPage extends StatefulWidget {
  const BlogPage({super.key});

  @override
  State<BlogPage> createState() => _BlogPageState();
}

class _BlogPageState extends State<BlogPage>
    with AutomaticKeepAliveClientMixin {
  final ApiService _api = ApiService();
  List<BlogArticle> _articles = [];
  bool _isLoading = true;
  bool _isOnline = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadArticles();
  }

  Future<void> _loadArticles() async {
    setState(() => _isLoading = true);
    try {
      _isOnline = await _api.checkHealth();
      if (_isOnline) {
        // Load ALL public articles (not just one user's)
        _articles = await _api.listArticles();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Load articles error: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(colors),
            Expanded(
              child: _isLoading
                  ? _buildArticleShimmer(colors)
                  : !_isOnline
                  ? _buildOffline(colors)
                  : _articles.isEmpty
                  ? _buildEmpty(colors)
                  : _buildArticleList(colors),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(AppColors colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Breathing.pagePaddingH,
        16,
        Breathing.pagePaddingH,
        8,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '博客',
                  style: TextStyle(
                    fontSize: Breathing.titleSize,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isOnline ? MiuiColors.green : MiuiColors.red,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _isOnline ? '${_articles.length} 篇文章' : '离线',
                      style: TextStyle(
                        fontSize: 14,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _buildActionButton(
            colors,
            Icons.refresh_rounded,
            '刷新',
            _loadArticles,
          ),
          // Only admin can write articles
          if (_isAdmin) ...[
            const SizedBox(width: 10),
            _buildActionButton(
              colors,
              Icons.add_rounded,
              '写文章',
              () => _openEditor(context, colors),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButton(
    AppColors colors,
    IconData icon,
    String tooltip,
    VoidCallback onTap,
  ) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: colors.textPrimary),
        ),
      ),
    );
  }

  Widget _buildOffline(AppColors colors) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_rounded, size: 56, color: colors.textTertiary),
          const SizedBox(height: 16),
          Text(
            '无法连接服务器',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '请检查网络连接后重试',
            style: TextStyle(fontSize: 14, color: colors.textTertiary),
          ),
          const SizedBox(height: 24),
          TextButton.icon(
            onPressed: _loadArticles,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('重试'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(AppColors colors) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.article_outlined,
            size: 64,
            color: colors.textTertiary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 20),
          Text(
            '还没有文章',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isAdmin ? '写下你的第一篇博客吧' : '博主还没有发布文章',
            style: TextStyle(fontSize: 15, color: colors.textTertiary),
          ),
          if (_isAdmin) ...[
            const SizedBox(height: 28),
            GestureDetector(
              onTap: () => _openEditor(context, AppColors.of(context)),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: MiuiColors.primary,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit_rounded, size: 18, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      '开始写作',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildArticleShimmer(AppColors colors) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        Breathing.pagePaddingH,
        8,
        Breathing.pagePaddingH,
        100,
      ),
      itemCount: 4,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _BlogShimmerBox(
                width: 200,
                height: 18,
                borderRadius: 8,
                colors: colors,
              ),
              const SizedBox(height: 12),
              _BlogShimmerBox(
                width: double.infinity,
                height: 12,
                borderRadius: 6,
                colors: colors,
              ),
              const SizedBox(height: 8),
              _BlogShimmerBox(
                width: 250,
                height: 12,
                borderRadius: 6,
                colors: colors,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _BlogShimmerBox(
                    width: 60,
                    height: 10,
                    borderRadius: 4,
                    colors: colors,
                  ),
                  const SizedBox(width: 12),
                  _BlogShimmerBox(
                    width: 40,
                    height: 10,
                    borderRadius: 4,
                    colors: colors,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildArticleList(AppColors colors) {
    return RefreshIndicator(
      onRefresh: _loadArticles,
      color: MiuiColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(
          Breathing.pagePaddingH,
          8,
          Breathing.pagePaddingH,
          100,
        ),
        itemCount: _articles.length,
        itemBuilder: (ctx, i) => _buildArticleCard(colors, _articles[i]),
      ),
    );
  }

  Widget _buildArticleCard(AppColors colors, BlogArticle article) {
    return GestureDetector(
      // Tap → open detail reading page
      onTap: () => _openDetail(context, colors, article),
      // Long press → admin actions (edit / delete)
      onLongPress: _isAdmin
          ? () => _showArticleActions(context, colors, article)
          : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: Breathing.cardGap),
        padding: const EdgeInsets.all(Breathing.cardPadding),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(Breathing.cardRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title + Public badge
            Row(
              children: [
                Expanded(
                  child: Text(
                    article.title,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                      color: colors.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (!article.isPublic)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: MiuiColors.orange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '私密',
                      style: TextStyle(
                        fontSize: 11,
                        color: MiuiColors.orange,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            // Summary
            if (article.summary.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                article.summary,
                style: TextStyle(
                  fontSize: 14,
                  color: colors.textSecondary,
                  height: 1.5,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            // Tags
            if (article.tags.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: article.tags
                    .take(4)
                    .map(
                      (tag) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: MiuiColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          tag,
                          style: const TextStyle(
                            fontSize: 12,
                            color: MiuiColors.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
            // Meta: date + views + likes + category
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 13,
                  color: colors.textTertiary,
                ),
                const SizedBox(width: 4),
                Text(
                  article.dateFormatted,
                  style: TextStyle(fontSize: 13, color: colors.textTertiary),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.visibility_outlined,
                  size: 14,
                  color: colors.textTertiary,
                ),
                const SizedBox(width: 4),
                Text(
                  '${article.views}',
                  style: TextStyle(fontSize: 13, color: colors.textTertiary),
                ),
                if (article.likeCount > 0) ...[
                  const SizedBox(width: 12),
                  Icon(
                    Icons.thumb_up_outlined,
                    size: 13,
                    color: colors.textTertiary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${article.likeCount}',
                    style: TextStyle(fontSize: 13, color: colors.textTertiary),
                  ),
                ],
                const Spacer(),
                if (article.category.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: MiuiColors.teal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      article.category,
                      style: const TextStyle(
                        fontSize: 11,
                        color: MiuiColors.teal,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                if (article.category.isEmpty)
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 12,
                    color: colors.textTertiary.withValues(alpha: 0.5),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ═══ Open article detail reading page ═══
  void _openDetail(BuildContext ctx, AppColors colors, BlogArticle article) {
    Navigator.of(ctx).push(
      swipeBackRoute(
        context: ctx,
        builder: (_) =>
            _BlogDetailPage(article: article, onEdited: () => _loadArticles()),
      ),
    );
  }

  // ═══ Admin-only action sheet (long press) ═══
  void _showArticleActions(
    BuildContext ctx,
    AppColors colors,
    BlogArticle article,
  ) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      builder: (c) => Container(
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              article.title,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            _ActionTile(
              icon: Icons.edit_rounded,
              label: '编辑',
              color: MiuiColors.primary,
              onTap: () {
                Navigator.pop(c);
                _openEditor(ctx, colors, article: article);
              },
            ),
            _ActionTile(
              icon: Icons.link_rounded,
              label: '复制博客链接',
              color: MiuiColors.teal,
              onTap: () {
                Navigator.pop(c);
                Clipboard.setData(ClipboardData(text: article.blogUrl));
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(
                    content: const Text('链接已复制'),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
              },
            ),
            _ActionTile(
              icon: article.isPublic
                  ? Icons.visibility_off_rounded
                  : Icons.visibility_rounded,
              label: article.isPublic ? '设为私密' : '设为公开',
              color: MiuiColors.orange,
              onTap: () async {
                Navigator.pop(c);
                final ok = await _api.updateArticle(
                  article.id,
                  isPublic: !article.isPublic,
                );
                if (ok && c.mounted) {
                  if (c.mounted) {
                    ScaffoldMessenger.of(c).showSnackBar(
                      SnackBar(
                        content: Text(article.isPublic ? '已设为私密' : '已设为公开'),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    );
                  }
                  _loadArticles();
                }
              },
            ),
            _ActionTile(
              icon: Icons.delete_rounded,
              label: '删除',
              color: MiuiColors.red,
              onTap: () {
                Navigator.pop(c);
                _confirmDelete(ctx, colors, article);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext ctx, AppColors colors, BlogArticle article) {
    showDialog(
      context: ctx,
      builder: (c) => AlertDialog(
        backgroundColor: colors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '确认删除',
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          '确定要删除「${article.title}」吗？此操作不可撤销。',
          style: TextStyle(color: colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text('取消', style: TextStyle(color: colors.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(c);
              final ok = await _api.deleteArticle(article.id);
              if (ok && c.mounted) {
                if (c.mounted) {
                  ScaffoldMessenger.of(c).showSnackBar(
                    SnackBar(
                      content: const Text('文章已删除'),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                }
                _loadArticles();
              }
            },
            child: const Text(
              '删除',
              style: TextStyle(
                color: MiuiColors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openEditor(BuildContext ctx, AppColors colors, {BlogArticle? article}) {
    Navigator.of(ctx).push(
      swipeBackRoute(
        context: ctx,
        builder: (_) =>
            _BlogEditorPage(article: article, onSaved: () => _loadArticles()),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
// Blog Detail Page — Full-screen article reader
// ═══════════════════════════════════════════════════
class _BlogDetailPage extends StatefulWidget {
  final BlogArticle article;
  final VoidCallback onEdited;
  const _BlogDetailPage({required this.article, required this.onEdited});

  @override
  State<_BlogDetailPage> createState() => _BlogDetailPageState();
}

class _BlogDetailPageState extends State<_BlogDetailPage> {
  final ApiService _api = ApiService();
  late BlogArticle _article;
  bool _isLoadingContent = false;

  @override
  void initState() {
    super.initState();
    _article = widget.article;
    // If content is empty, fetch full article from server
    if (_article.content.isEmpty) {
      _fetchFullArticle();
    }
  }

  Future<void> _fetchFullArticle() async {
    setState(() => _isLoadingContent = true);
    try {
      final full = await _api.getArticle(_article.id);
      if (full != null && mounted) {
        setState(() => _article = full);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Fetch article error: $e');
    }
    if (mounted) setState(() => _isLoadingContent = false);
  }

  /// Share article via copy + system share sheet with a preview card.
  Future<void> _shareArticle(BlogArticle article) async {
    final url = article.blogUrl;
    final colors = AppColors.of(context);

    // Copy immediately so even if user cancels, link is in clipboard.
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;

    // Show a share-preview sheet matching the file-share style
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 5,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: colors.textTertiary.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 6),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: MiuiColors.teal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.share_rounded,
                      color: MiuiColors.teal,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '分享博客',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          article.title,
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.textTertiary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Link preview
            Container(
              margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: MiuiColors.teal.withValues(alpha: 0.2),
                  width: 0.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.link_rounded,
                        size: 14,
                        color: colors.textTertiary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '博客链接',
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.textTertiary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SelectableText(
                    url,
                    style: TextStyle(
                      fontSize: 13,
                      color: colors.textPrimary,
                      fontFamily: 'monospace',
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                '✓ 已复制到剪贴板',
                style: TextStyle(
                  fontSize: 12,
                  color: MiuiColors.green,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(ctx, 'close'),
                      icon: const Icon(Icons.close_rounded, size: 18),
                      label: const Text('完成'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.textSecondary,
                        side: BorderSide(color: colors.divider),
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(ctx, 'share'),
                      icon: const Icon(Icons.ios_share_rounded, size: 18),
                      label: const Text('分享到...'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MiuiColors.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: MediaQuery.of(ctx).padding.bottom + 20),
          ],
        ),
      ),
    );

    if (choice == 'share' && mounted) {
      final summary = article.summary.isNotEmpty
          ? '\n\n${article.summary}'
          : '';
      await SharePlus.instance.share(
        ShareParams(
          text: '📝 ${article.title}$summary\n\n🔗 $url',
          subject: article.title,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: colors.textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.share_rounded,
              size: 20,
              color: colors.textSecondary,
            ),
            tooltip: '分享',
            onPressed: () => _shareArticle(_article),
          ),
          if (_isAdmin)
            IconButton(
              icon: Icon(
                Icons.edit_outlined,
                size: 20,
                color: MiuiColors.primary,
              ),
              tooltip: '编辑',
              onPressed: () {
                Navigator.of(context).pushReplacement(
                  swipeBackRoute(
                    context: context,
                    builder: (_) => _BlogEditorPage(
                      article: _article,
                      onSaved: widget.onEdited,
                    ),
                  ),
                );
              },
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Title area ───
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              child: Text(
                _article.title,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  height: 1.3,
                  color: colors.textPrimary,
                ),
              ),
            ),

            // ─── Meta row ───
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
              child: Wrap(
                spacing: 12,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 13,
                        color: colors.textTertiary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _article.dateFormatted,
                        style: TextStyle(
                          fontSize: 13,
                          color: colors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.remove_red_eye_outlined,
                        size: 14,
                        color: colors.textTertiary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${_article.views}',
                        style: TextStyle(
                          fontSize: 13,
                          color: colors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                  if (_article.likeCount > 0)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.thumb_up_outlined,
                          size: 13,
                          color: colors.textTertiary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${_article.likeCount}',
                          style: TextStyle(
                            fontSize: 13,
                            color: colors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  if (_article.category.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: MiuiColors.teal.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _article.category,
                        style: const TextStyle(
                          fontSize: 11,
                          color: MiuiColors.teal,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  if (!_article.isPublic)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: MiuiColors.orange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        '私密',
                        style: TextStyle(
                          fontSize: 11,
                          color: MiuiColors.orange,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ─── Tags ───
            if (_article.tags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _article.tags
                      .map(
                        (tag) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: MiuiColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            '#$tag',
                            style: const TextStyle(
                              fontSize: 13,
                              color: MiuiColors.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),

            // ─── Divider ───
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Divider(
                color: colors.divider.withValues(alpha: 0.5),
                height: 1,
              ),
            ),

            // ─── Article content ───
            if (_isLoadingContent)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _BlogShimmerBox(
                      width: double.infinity,
                      height: 16,
                      borderRadius: 6,
                      colors: colors,
                    ),
                    const SizedBox(height: 12),
                    _BlogShimmerBox(
                      width: double.infinity,
                      height: 16,
                      borderRadius: 6,
                      colors: colors,
                    ),
                    const SizedBox(height: 12),
                    _BlogShimmerBox(
                      width: 240,
                      height: 16,
                      borderRadius: 6,
                      colors: colors,
                    ),
                    const SizedBox(height: 20),
                    _BlogShimmerBox(
                      width: double.infinity,
                      height: 16,
                      borderRadius: 6,
                      colors: colors,
                    ),
                    const SizedBox(height: 12),
                    _BlogShimmerBox(
                      width: double.infinity,
                      height: 16,
                      borderRadius: 6,
                      colors: colors,
                    ),
                    const SizedBox(height: 12),
                    _BlogShimmerBox(
                      width: 180,
                      height: 16,
                      borderRadius: 6,
                      colors: colors,
                    ),
                  ],
                ),
              )
            else if (_article.content.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: _MarkdownRenderer(
                  content: _article.content,
                  colors: colors,
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(top: 48),
                child: Center(
                  child: Text(
                    '内容加载失败',
                    style: TextStyle(fontSize: 15, color: colors.textTertiary),
                  ),
                ),
              ),

            // ─── End mark ───
            const SizedBox(height: 48),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.done_all_rounded,
                      size: 16,
                      color: colors.textTertiary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '全文完',
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: colors.textPrimary,
        ),
      ),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      dense: true,
      visualDensity: const VisualDensity(vertical: -1),
    );
  }
}

// ═══════════════════════════════════════════════════
// Blog Editor Page — Full-screen Markdown editor
// ═══════════════════════════════════════════════════
class _BlogEditorPage extends StatefulWidget {
  final BlogArticle? article;
  final VoidCallback onSaved;
  const _BlogEditorPage({this.article, required this.onSaved});

  @override
  State<_BlogEditorPage> createState() => _BlogEditorPageState();
}

class _BlogEditorPageState extends State<_BlogEditorPage> {
  final ApiService _api = ApiService();
  late TextEditingController _titleCtrl;
  late TextEditingController _contentCtrl;
  late TextEditingController _tagsCtrl;
  bool _isPublic = true;
  bool _isSaving = false;
  bool _isPreview = false;
  bool _hasChanges = false;

  bool get _isEditing => widget.article != null;

  @override
  void initState() {
    super.initState();
    final a = widget.article;
    _titleCtrl = TextEditingController(text: a?.title ?? '');
    _contentCtrl = TextEditingController(text: a?.content ?? '');
    _tagsCtrl = TextEditingController(text: a?.tags.join(', ') ?? '');
    _isPublic = a?.isPublic ?? true;

    _titleCtrl.addListener(_onChanged);
    _contentCtrl.addListener(_onChanged);
    _tagsCtrl.addListener(_onChanged);
  }

  void _onChanged() {
    if (!_hasChanges && mounted) setState(() => _hasChanges = true);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    _tagsCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    final content = _contentCtrl.text.trim();
    if (title.isEmpty || content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('标题和内容不能为空'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    final tags = _tagsCtrl.text
        .split(RegExp(r'[,，、\s]+'))
        .where((t) => t.trim().isNotEmpty)
        .map((t) => t.trim())
        .toList();

    bool ok;
    if (_isEditing) {
      ok = await _api.updateArticle(
        widget.article!.id,
        title: title,
        content: content,
        tags: tags,
        isPublic: _isPublic,
      );
    } else {
      final result = await _api.createArticle(
        title: title,
        content: content,
        tags: tags,
        isPublic: _isPublic,
      );
      ok = result != null;
    }

    if (mounted) {
      setState(() => _isSaving = false);
      if (ok) {
        widget.onSaved();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing ? '文章已更新' : '文章已发布'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('保存失败，请重试'),
            backgroundColor: MiuiColors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (c) {
        final clr = AppColors.of(c);
        return AlertDialog(
          backgroundColor: clr.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            '放弃更改？',
            style: TextStyle(
              color: clr.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            '你有未保存的更改，确定要离开吗？',
            style: TextStyle(color: clr.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text('继续编辑', style: TextStyle(color: clr.textSecondary)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('放弃', style: TextStyle(color: MiuiColors.red)),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) {
          final shouldPop = await _onWillPop();
          if (shouldPop && context.mounted) Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          backgroundColor: colors.card,
          elevation: 0,
          scrolledUnderElevation: 0.5,
          leading: IconButton(
            icon: Icon(Icons.close_rounded, color: colors.textPrimary),
            onPressed: () async {
              if (_hasChanges) {
                final shouldPop = await _onWillPop();
                if (shouldPop && context.mounted) Navigator.of(context).pop();
              } else {
                Navigator.of(context).pop();
              }
            },
          ),
          title: Text(
            _isEditing ? '编辑文章' : '写文章',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
          centerTitle: true,
          actions: [
            // Preview toggle
            IconButton(
              icon: Icon(
                _isPreview ? Icons.edit_rounded : Icons.preview_rounded,
                size: 22,
                color: colors.textSecondary,
              ),
              onPressed: () => setState(() => _isPreview = !_isPreview),
              tooltip: _isPreview ? '编辑' : '预览',
            ),
            // Save/Publish
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: GestureDetector(
                onTap: _isSaving ? null : _save,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _isSaving
                        ? MiuiColors.primary.withValues(alpha: 0.5)
                        : MiuiColors.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _isEditing ? '更新' : '发布',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
        body: _isPreview ? _buildPreview(colors) : _buildEditor(colors),
      ),
    );
  }

  Widget _buildEditor(AppColors colors) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          TextField(
            controller: _titleCtrl,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: colors.textPrimary,
              letterSpacing: -0.5,
            ),
            decoration: InputDecoration(
              hintText: '文章标题',
              hintStyle: TextStyle(
                color: colors.textTertiary,
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            maxLines: null,
          ),
          const SizedBox(height: 8),
          // Tags
          TextField(
            controller: _tagsCtrl,
            style: TextStyle(fontSize: 14, color: MiuiColors.primary),
            decoration: InputDecoration(
              hintText: '标签（用逗号分隔，如：技术, 生活）',
              hintStyle: TextStyle(color: colors.textTertiary, fontSize: 14),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              prefixIcon: Icon(
                Icons.tag_rounded,
                size: 18,
                color: colors.textTertiary,
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 26),
            ),
          ),
          // Public toggle
          Row(
            children: [
              Icon(Icons.public_rounded, size: 18, color: colors.textTertiary),
              const SizedBox(width: 8),
              Text(
                '公开发布',
                style: TextStyle(fontSize: 14, color: colors.textSecondary),
              ),
              const Spacer(),
              Switch.adaptive(
                value: _isPublic,
                onChanged: (v) => setState(() {
                  _isPublic = v;
                  _hasChanges = true;
                }),
                activeTrackColor: MiuiColors.primary,
              ),
            ],
          ),
          Divider(color: colors.divider, height: 24),
          // Markdown hint with guide link
          GestureDetector(
            onTap: () => Navigator.of(context).push(
              swipeBackRoute(
                context: context,
                builder: (_) => const _MarkdownGuidePage(),
              ),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: MiuiColors.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: MiuiColors.primary.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '支持 Markdown：# 标题、**粗体**、*斜体*、- 列表、> 引用、```代码```',
                      style: TextStyle(
                        fontSize: 12,
                        color: MiuiColors.primary.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: MiuiColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '查看规则',
                      style: TextStyle(
                        fontSize: 11,
                        color: MiuiColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Content
          TextField(
            controller: _contentCtrl,
            style: TextStyle(
              fontSize: 16,
              color: colors.textPrimary,
              height: 1.8,
            ),
            decoration: InputDecoration(
              hintText: '在这里写下你的文章...\n\n支持 Markdown 格式',
              hintStyle: TextStyle(
                color: colors.textTertiary,
                fontSize: 16,
                height: 1.8,
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            maxLines: null,
            minLines: 15,
            keyboardType: TextInputType.multiline,
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildPreview(AppColors colors) {
    final title = _titleCtrl.text.trim();
    final content = _contentCtrl.text.trim();
    final tags = _tagsCtrl.text
        .split(RegExp(r'[,，、\s]+'))
        .where((t) => t.trim().isNotEmpty)
        .map((t) => t.trim())
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(Breathing.cardRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Preview badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: MiuiColors.orange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '预览',
                style: TextStyle(
                  fontSize: 12,
                  color: MiuiColors.orange,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Title
            Text(
              title.isEmpty ? '(无标题)' : title,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            // Tags
            if (tags.isNotEmpty)
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: tags
                    .map(
                      (t) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: MiuiColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          t,
                          style: const TextStyle(
                            fontSize: 12,
                            color: MiuiColors.primary,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            const SizedBox(height: 16),
            Divider(color: colors.divider),
            const SizedBox(height: 16),
            // Content rendered as simple markdown
            _MarkdownRenderer(content: content, colors: colors),
          ],
        ),
      ),
    );
  }
}

// ═══ Enhanced Markdown Renderer Widget ═══
class _MarkdownRenderer extends StatelessWidget {
  final String content;
  final AppColors colors;
  const _MarkdownRenderer({required this.content, required this.colors});

  @override
  Widget build(BuildContext context) {
    if (content.isEmpty) {
      return Text(
        '(无内容)',
        style: TextStyle(
          color: colors.textTertiary,
          fontStyle: FontStyle.italic,
        ),
      );
    }
    final lines = content.split('\n');
    final widgets = <Widget>[];
    bool inCodeBlock = false;
    String codeLanguage = '';
    StringBuffer codeBuffer = StringBuffer();

    for (var line in lines) {
      // Code blocks
      if (line.trimLeft().startsWith('```')) {
        if (inCodeBlock) {
          widgets.add(
            _buildCodeBlock(
              codeBuffer.toString().trimRight(),
              codeLanguage,
              context,
            ),
          );
          codeBuffer.clear();
          inCodeBlock = false;
          codeLanguage = '';
        } else {
          inCodeBlock = true;
          codeLanguage = line.trimLeft().substring(3).trim();
        }
        continue;
      }
      if (inCodeBlock) {
        codeBuffer.writeln(line);
        continue;
      }

      // Horizontal rule
      if (RegExp(r'^[-*_]{3,}\s*\$').hasMatch(line.trim())) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Divider(color: colors.divider, height: 1),
          ),
        );
        continue;
      }

      // Headers (#### h4 support added)
      if (line.startsWith('#### ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 4),
            child: Text(
              line.substring(5),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
          ),
        );
      } else if (line.startsWith('### ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 6),
            child: Text(
              line.substring(4),
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
          ),
        );
      } else if (line.startsWith('## ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 20, bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.substring(3),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 2,
                  width: 40,
                  decoration: BoxDecoration(
                    color: MiuiColors.primary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ],
            ),
          ),
        );
      } else if (line.startsWith('# ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 24, bottom: 10),
            child: Text(
              line.substring(2),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: colors.textPrimary,
              ),
            ),
          ),
        );
      }
      // Blockquote
      else if (line.startsWith('> ')) {
        widgets.add(
          Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            decoration: BoxDecoration(
              border: const Border(
                left: BorderSide(color: MiuiColors.primary, width: 3),
              ),
              color: MiuiColors.primary.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(8),
                bottomRight: Radius.circular(8),
              ),
            ),
            child: _buildRichText(line.substring(2), colors),
          ),
        );
      }
      // Image: ![alt](url)
      else if (RegExp(r'^!\[.*\]\(.*\)').hasMatch(line.trim())) {
        final match = RegExp(r'^!\[(.*)\]\((.+?)\)').firstMatch(line.trim());
        if (match != null) {
          final alt = match.group(1) ?? '';
          final url = match.group(2) ?? '';
          widgets.add(
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      url,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (_, __, ___) => Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.broken_image_rounded,
                              size: 20,
                              color: colors.textTertiary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                alt.isNotEmpty ? alt : '图片加载失败',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: colors.textTertiary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (alt.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      alt,
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textTertiary,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          );
        }
      }
      // Ordered list (1. 2. 3.)
      else if (RegExp(r'^\d+\.\s').hasMatch(line)) {
        final match = RegExp(r'^(\d+)\.\s(.*)').firstMatch(line);
        if (match != null) {
          widgets.add(
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 4, bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 28,
                    child: Text(
                      '${match.group(1)}.',
                      style: TextStyle(
                        fontSize: 15,
                        color: colors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(child: _buildRichText(match.group(2)!, colors)),
                ],
              ),
            ),
          );
        }
      }
      // Unordered list
      else if (line.startsWith('- ') || line.startsWith('* ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(left: 8, top: 4, bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '  \u2022  ',
                  style: TextStyle(
                    fontSize: 15,
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Expanded(child: _buildRichText(line.substring(2), colors)),
              ],
            ),
          ),
        );
      }
      // Task list - [ ] and - [x]
      else if (line.startsWith('- [ ] ') ||
          line.startsWith('- [x] ') ||
          line.startsWith('- [X] ')) {
        final checked = line.startsWith('- [x]') || line.startsWith('- [X]');
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(left: 8, top: 4, bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  checked
                      ? Icons.check_box_rounded
                      : Icons.check_box_outline_blank_rounded,
                  size: 18,
                  color: checked ? MiuiColors.green : colors.textTertiary,
                ),
                const SizedBox(width: 8),
                Expanded(child: _buildRichText(line.substring(6), colors)),
              ],
            ),
          ),
        );
      }
      // Empty line
      else if (line.trim().isEmpty) {
        widgets.add(const SizedBox(height: 8));
      }
      // Normal paragraph
      else {
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: _buildRichText(line, colors),
          ),
        );
      }
    }

    // Handle unclosed code block
    if (inCodeBlock && codeBuffer.isNotEmpty) {
      widgets.add(
        _buildCodeBlock(
          codeBuffer.toString().trimRight(),
          codeLanguage,
          context,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  Widget _buildCodeBlock(String code, String language, BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: colors.isDark
            ? const Color(0xFF1E1E1E)
            : const Color(0xFFF5F5FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.divider.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Language label + copy button
          if (language.isNotEmpty || code.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: colors.isDark
                    ? const Color(0xFF2A2A2A)
                    : const Color(0xFFEEEEF3),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  if (language.isNotEmpty)
                    Text(
                      language,
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.textTertiary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: code));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('代码已复制'),
                          behavior: SnackBarBehavior.floating,
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.copy_rounded,
                          size: 14,
                          color: colors.textTertiary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '复制',
                          style: TextStyle(
                            fontSize: 11,
                            color: colors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: SelectableText(
              code,
              style: TextStyle(
                fontSize: 13,
                fontFamily: 'monospace',
                color: colors.textPrimary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRichText(String text, AppColors colors) {
    // Parse inline: **bold**, *italic*, `code`, [link](url), ~~strikethrough~~
    final spans = <InlineSpan>[];
    final pattern = RegExp(
      r'(\*\*(.+?)\*\*)|(\*(.+?)\*)|(`([^`]+)`)|(\[([^\]]+)\]\(([^)]+)\))|(~~(.+?)~~)',
    );
    int lastEnd = 0;

    for (final match in pattern.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(InlineSpan(text: text.substring(lastEnd, match.start)));
      }
      if (match.group(2) != null) {
        spans.add(InlineSpan(text: match.group(2)!, bold: true));
      } else if (match.group(4) != null) {
        spans.add(InlineSpan(text: match.group(4)!, italic: true));
      } else if (match.group(6) != null) {
        spans.add(InlineSpan(text: match.group(6)!, code: true));
      } else if (match.group(8) != null && match.group(9) != null) {
        spans.add(InlineSpan(text: match.group(8)!, link: match.group(9)));
      } else if (match.group(11) != null) {
        spans.add(InlineSpan(text: match.group(11)!, strikethrough: true));
      }
      lastEnd = match.end;
    }
    if (lastEnd < text.length) {
      spans.add(InlineSpan(text: text.substring(lastEnd)));
    }

    if (spans.isEmpty) {
      return Text(
        text,
        style: TextStyle(fontSize: 15, color: colors.textPrimary, height: 1.7),
      );
    }

    return RichText(
      text: TextSpan(
        children: spans.map((s) {
          if (s.code) {
            return TextSpan(
              text: ' \${s.text} ',
              style: TextStyle(
                fontSize: 13,
                fontFamily: 'monospace',
                backgroundColor: colors.isDark
                    ? const Color(0xFF2C2C2E)
                    : const Color(0xFFF0F0F5),
                color: MiuiColors.primary,
              ),
            );
          }
          if (s.link != null) {
            return TextSpan(
              text: s.text,
              style: const TextStyle(
                fontSize: 15,
                color: MiuiColors.blue,
                decoration: TextDecoration.underline,
                decorationColor: MiuiColors.blue,
                height: 1.7,
              ),
            );
          }
          return TextSpan(
            text: s.text,
            style: TextStyle(
              fontSize: 15,
              color: colors.textPrimary,
              fontWeight: s.bold ? FontWeight.w700 : FontWeight.w400,
              fontStyle: s.italic ? FontStyle.italic : FontStyle.normal,
              decoration: s.strikethrough ? TextDecoration.lineThrough : null,
              height: 1.7,
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ═══ Markdown Guide Page ═══
class _MarkdownGuidePage extends StatelessWidget {
  const _MarkdownGuidePage();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: colors.textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Markdown 规则',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Intro
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: MiuiColors.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.auto_awesome_rounded,
                    size: 20,
                    color: MiuiColors.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '使用 Markdown 语法可以让你的文章更加美观，以下是常用语法参考。',
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            _guideSection('标题', [
              _GuideItem('# 一级标题', '最大标题'),
              _GuideItem('## 二级标题', '章节标题'),
              _GuideItem('### 三级标题', '小节标题'),
              _GuideItem('#### 四级标题', '子标题'),
            ], colors),

            _guideSection('文本样式', [
              _GuideItem('**粗体文本**', '加粗显示'),
              _GuideItem('*斜体文本*', '斜体显示'),
              _GuideItem('~~删除线~~', '删除线效果'),
              _GuideItem('`行内代码`', '代码样式显示'),
            ], colors),

            _guideSection('列表', [
              _GuideItem('- 项目一\n- 项目二\n- 项目三', '无序列表'),
              _GuideItem('1. 第一步\n2. 第二步\n3. 第三步', '有序列表'),
              _GuideItem('- [ ] 未完成\n- [x] 已完成', '任务列表'),
            ], colors),

            _guideSection('引用和代码', [
              _GuideItem('> 这是一段引用文本', '引用块'),
              _GuideItem('```python\nprint("Hello")\n```', '代码块（支持语言标注）'),
            ], colors),

            _guideSection('链接和图片', [
              _GuideItem('[链接文本](https://example.com)', '超链接'),
              _GuideItem('![图片描述](https://example.com/img.jpg)', '图片'),
            ], colors),

            _guideSection('分割线', [_GuideItem('---', '水平分割线')], colors),

            const SizedBox(height: 20),

            // Live preview section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.card,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.preview_rounded,
                        size: 18,
                        color: MiuiColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '渲染示例',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Divider(color: colors.divider, height: 1),
                  const SizedBox(height: 12),
                  _MarkdownRenderer(
                    content:
                        '## 欢迎使用 Markdown\n\n这是一段 **粗体** 和 *斜体* 文本的示例。\n\n> 写作是思考的最佳方式\n\n- 支持无序列表\n- 支持 `行内代码`\n\n1. 支持有序列表\n2. 自动编号\n\n---\n\n```dart\nprint("Hello Markdown!");\n```',
                    colors: colors,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _guideSection(String title, List<_GuideItem> items, AppColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        ...items.map(
          (item) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colors.isDark
                        ? const Color(0xFF1E1E1E)
                        : const Color(0xFFF5F5FA),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    item.syntax,
                    style: TextStyle(
                      fontSize: 13,
                      fontFamily: 'monospace',
                      color: MiuiColors.primary,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  item.description,
                  style: TextStyle(fontSize: 12, color: colors.textTertiary),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _GuideItem {
  final String syntax;
  final String description;
  const _GuideItem(this.syntax, this.description);
}

class InlineSpan {
  final String text;
  final bool bold;
  final bool italic;
  final bool code;
  final String? link;
  final bool strikethrough;
  InlineSpan({
    required this.text,
    this.bold = false,
    this.italic = false,
    this.code = false,
    this.link,
    this.strikethrough = false,
  });
}

// ═══ Blog Shimmer Loading Widget ═══
class _BlogShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;
  final AppColors colors;
  const _BlogShimmerBox({
    required this.width,
    required this.height,
    required this.borderRadius,
    required this.colors,
  });
  @override
  State<_BlogShimmerBox> createState() => _BlogShimmerBoxState();
}

class _BlogShimmerBoxState extends State<_BlogShimmerBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final s = _ctrl.value;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              colors: [
                widget.colors.surface,
                widget.colors.card,
                widget.colors.surface,
              ],
              stops: [
                (s - 0.3).clamp(0.0, 1.0),
                s.clamp(0.0, 1.0),
                (s + 0.3).clamp(0.0, 1.0),
              ],
              begin: const Alignment(-1.0, -0.3),
              end: const Alignment(2.0, 0.3),
            ),
          ),
        );
      },
    );
  }
}
