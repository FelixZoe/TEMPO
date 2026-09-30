#if os(macOS)
import SwiftUI

struct RSSScreen: View {
  @ObservedObject var store: RSSStore
  @State private var filter: RSSArticleFilter = .unread
  @State private var query = ""
  @State private var selectedFeedID: String?

  private var visibleArticles: [RSSArticle] {
    store.filteredArticles(
      filter: filter,
      query: query,
      feedID: selectedFeedID,
      folderID: nil
    )
  }

  var body: some View {
    NavigationSplitView {
      List(selection: $selectedFeedID) {
        Label("全部订阅", systemImage: "dot.radiowaves.left.and.right")
          .tag(String?.none)
        ForEach(store.subscriptions) { subscription in
          HStack(spacing: 8) {
            Text(subscription.title)
              .lineLimit(1)
            Spacer(minLength: 8)
            let count = store.unreadCount(for: subscription.id)
            if count > 0 {
              Text("\(count)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            }
          }
          .tag(Optional(subscription.id))
        }
      }
      .navigationTitle("订阅")
      .navigationSplitViewColumnWidth(min: 180, ideal: 220)
    } detail: {
      VStack(spacing: 0) {
        header
        Divider()
        if store.subscriptions.isEmpty {
          ContentUnavailableView(
            "还没有订阅",
            systemImage: "dot.radiowaves.left.and.right",
            description: Text("请先在移动端添加订阅，Tempo 会通过自托管服务同步到这里。")
          )
        } else if visibleArticles.isEmpty {
          ContentUnavailableView.search(text: query)
        } else {
          List(visibleArticles) { article in
            articleRow(article)
          }
          .listStyle(.inset)
        }
      }
      .navigationTitle(selectedFeedTitle)
      .searchable(text: $query, placement: .toolbar, prompt: "搜索文章")
    }
    .task { await store.refreshIfNeeded() }
  }

  private var header: some View {
    HStack(spacing: 12) {
      Picker("范围", selection: $filter) {
        ForEach(RSSArticleFilter.allCases) { item in
          Text(item.title).tag(item)
        }
      }
      .pickerStyle(.segmented)
      .frame(maxWidth: 300)

      Spacer()

      if case .refreshing = store.phase {
        ProgressView()
          .controlSize(.small)
      }
      Button {
        Task { await store.refresh() }
      } label: {
        Label("刷新", systemImage: "arrow.clockwise")
      }
      .disabled(store.subscriptions.isEmpty || store.phase == .refreshing)
    }
    .padding(16)
  }

  @ViewBuilder
  private func articleRow(_ article: RSSArticle) -> some View {
    let date = article.publishedAt ?? article.fetchedAt
    HStack(alignment: .top, spacing: 12) {
      Circle()
        .fill(article.isRead ? Color.clear : QingxuPalette.accent)
        .frame(width: 6, height: 6)
        .padding(.top, 7)

      VStack(alignment: .leading, spacing: 6) {
        Text(article.title)
          .font(.headline)
          .foregroundStyle(article.isRead ? Color.secondary : Color.primary)
          .lineLimit(2)
        Text(article.summary)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .lineLimit(2)
        HStack(spacing: 8) {
          Text(article.feedTitle)
          Text(date, style: .relative)
        }
        .font(.caption)
        .foregroundStyle(.tertiary)
      }

      Spacer(minLength: 12)

      if let url = URL(string: article.link), !article.link.isEmpty {
        Link(destination: url) {
          Image(systemName: "arrow.up.right.square")
        }
        .buttonStyle(.borderless)
        .simultaneousGesture(TapGesture().onEnded { store.markRead(article) })
      }
    }
    .padding(.vertical, 6)
    .contextMenu {
      Button(article.isRead ? "标为未读" : "标为已读") { store.toggleRead(article) }
      Button(article.isStarred ? "取消收藏" : "收藏") { store.toggleStarred(article) }
    }
  }

  private var selectedFeedTitle: String {
    guard let selectedFeedID,
          let subscription = store.subscriptions.first(where: { $0.id == selectedFeedID })
    else { return "RSS" }
    return subscription.title
  }
}
#endif
