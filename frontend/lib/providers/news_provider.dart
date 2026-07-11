import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/news_article_model.dart';
import '../services/news_service.dart';
import 'auth_provider.dart';

final newsServiceProvider = Provider<NewsService>((ref) {
  return NewsService(ref.read(apiServiceProvider));
});

enum NewsStatus { initial, loading, loaded, error }

// Matches the backend's fixed pageSize — a page returning fewer than this is
// treated as the last page, so we don't fire one final request that just
// comes back empty.
const _pageSize = 20;

class NewsState {
  final NewsStatus status;
  final List<NewsArticleModel> articles;
  final String? errorMessage;
  final int page;
  final bool hasMore;
  final bool isLoadingMore;

  const NewsState({
    this.status = NewsStatus.initial,
    this.articles = const [],
    this.errorMessage,
    this.page = 1,
    this.hasMore = true,
    this.isLoadingMore = false,
  });

  NewsState copyWith({
    NewsStatus? status,
    List<NewsArticleModel>? articles,
    String? errorMessage,
    int? page,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return NewsState(
      status: status ?? this.status,
      articles: articles ?? this.articles,
      errorMessage: errorMessage,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

class NewsNotifier extends StateNotifier<NewsState> {
  final NewsService _service;

  // Bumped by every load() (refresh). loadMore() captures this before its
  // await and checks it again after — if a refresh happened in between, the
  // in-flight loadMore's page is stale and gets discarded instead of being
  // appended onto the freshly-reloaded page-1 list.
  int _requestId = 0;

  NewsNotifier(this._service) : super(const NewsState()) {
    load();
  }

  Future<void> load() async {
    final requestId = ++_requestId;
    state = state.copyWith(status: NewsStatus.loading, errorMessage: null);
    try {
      final articles = await _service.getNews(page: 1);
      if (requestId != _requestId) return;
      state = state.copyWith(
        status: NewsStatus.loaded,
        articles: articles,
        page: 1,
        hasMore: articles.length >= _pageSize,
        isLoadingMore: false,
      );
    } catch (e) {
      if (requestId != _requestId) return;
      state = state.copyWith(status: NewsStatus.error, errorMessage: e.toString(), isLoadingMore: false);
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore || state.status != NewsStatus.loaded) return;

    final requestId = _requestId;
    final nextPage = state.page + 1;
    state = state.copyWith(isLoadingMore: true);
    try {
      final newArticles = await _service.getNews(page: nextPage);
      if (requestId != _requestId) return; // superseded by a refresh — discard

      // De-dupe by URL: NewsAPI's result set can shift between requests as
      // new articles are published, so pagination isn't guaranteed disjoint.
      final existingUrls = state.articles.map((a) => a.url).toSet();
      final deduped = newArticles.where((a) => a.url.isEmpty || !existingUrls.contains(a.url)).toList();

      state = state.copyWith(
        articles: [...state.articles, ...deduped],
        page: nextPage,
        hasMore: newArticles.length >= _pageSize,
        isLoadingMore: false,
      );
    } catch (e) {
      if (requestId != _requestId) return;
      state = state.copyWith(isLoadingMore: false, errorMessage: e.toString());
    }
  }
}

final newsProvider = StateNotifierProvider<NewsNotifier, NewsState>((ref) {
  return NewsNotifier(ref.read(newsServiceProvider));
});
