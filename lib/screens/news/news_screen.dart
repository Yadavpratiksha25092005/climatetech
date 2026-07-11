import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/dark_palette.dart';
import '../../models/news_article_model.dart';
import '../../providers/news_provider.dart';

class NewsScreen extends ConsumerStatefulWidget {
  const NewsScreen({super.key});

  @override
  ConsumerState<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends ConsumerState<NewsScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels < _scrollController.position.maxScrollExtent - 300) return;
    // NewsNotifier.loadMore() already no-ops while a load is in flight or
    // there's no more data, but checking here too avoids firing a call into
    // the notifier on every scroll-position update while inside the 300px
    // threshold, not just once.
    final state = ref.read(newsProvider);
    if (state.isLoadingMore || !state.hasMore) return;
    ref.read(newsProvider.notifier).loadMore();
  }

  Future<void> _openArticle(String url) async {
    if (url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;

    bool launched = false;
    try {
      launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      launched = false;
    }

    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open this article.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(newsProvider);

    return Scaffold(
      backgroundColor: DarkPalette.navyDeep,
      appBar: AppBar(
        backgroundColor: DarkPalette.navyDeep,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: DarkPalette.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: const Text('Climate news', style: TextStyle(color: DarkPalette.textPrimary, fontSize: 16)),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(newsProvider.notifier).load(),
        color: DarkPalette.leafGreen,
        backgroundColor: DarkPalette.navyCard,
        child: _buildBody(state),
      ),
    );
  }

  Widget _buildBody(NewsState state) {
    if (state.status == NewsStatus.loading && state.articles.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: DarkPalette.leafGreen));
    }
    if (state.status == NewsStatus.error && state.articles.isEmpty) {
      return _buildErrorState(state.errorMessage);
    }
    if (state.articles.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          Padding(
            padding: EdgeInsets.only(top: 80),
            child: Center(child: Text('No climate news right now.', style: TextStyle(color: DarkPalette.textMuted, fontSize: 13))),
          ),
        ],
      );
    }

    return ListView.separated(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
      itemCount: state.articles.length + (state.hasMore ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        if (i >= state.articles.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator(color: DarkPalette.leafGreen, strokeWidth: 2)),
          );
        }
        return _articleCard(state.articles[i]);
      },
    );
  }

  Widget _articleCard(NewsArticleModel article) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _openArticle(article.url),
      child: Container(
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (article.imageUrl.isNotEmpty)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  article.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _imagePlaceholder(),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    article.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: DarkPalette.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          article.sourceName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: DarkPalette.leafGreen, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (article.publishedAt != null)
                        Text(_timeAgo(article.publishedAt!), style: const TextStyle(color: DarkPalette.textMuted, fontSize: 11)),
                    ],
                  ),
                  if (article.description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      article.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: DarkPalette.textSecondary, fontSize: 12, height: 1.4),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      color: Colors.white.withOpacity(0.06),
      child: const Center(child: Icon(Icons.image_outlined, color: DarkPalette.textMuted, size: 32)),
    );
  }

  String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time.toLocal());
    if (diff.isNegative) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(time.toLocal());
  }

  Widget _buildErrorState(String? message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, color: DarkPalette.textMuted, size: 40),
            const SizedBox(height: 12),
            Text(
              message ?? 'Could not load climate news.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: DarkPalette.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.read(newsProvider.notifier).load(),
              style: ElevatedButton.styleFrom(backgroundColor: DarkPalette.leafGreen, foregroundColor: Colors.black),
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
