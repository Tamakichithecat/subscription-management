import Foundation

struct SubscriptionCategory: Identifiable, Sendable, Hashable {
    let id: UUID
    var name: String
    var icon: String        // SF Symbols 名（例: "tv.fill"）
    var color: String       // HEX カラーコード（例: "#E74C3C"）
    var isDefault: Bool
}

extension SubscriptionCategory {
    /// デフォルトカテゴリー一覧（Supabase から取得できない場合のフォールバック）
    static let defaults: [SubscriptionCategory] = [
        .init(id: UUID(), name: "エンタメ",          icon: "tv.fill",             color: "#E74C3C", isDefault: true),
        .init(id: UUID(), name: "音楽",              icon: "music.note",          color: "#9B59B6", isDefault: true),
        .init(id: UUID(), name: "クラウド",           icon: "icloud.fill",         color: "#3498DB", isDefault: true),
        .init(id: UUID(), name: "ビジネス",           icon: "briefcase.fill",      color: "#2ECC71", isDefault: true),
        .init(id: UUID(), name: "ニュース",           icon: "newspaper.fill",      color: "#F39C12", isDefault: true),
        .init(id: UUID(), name: "ゲーム",             icon: "gamecontroller.fill", color: "#1ABC9C", isDefault: true),
        .init(id: UUID(), name: "学習",              icon: "book.fill",           color: "#D35400", isDefault: true),
        .init(id: UUID(), name: "ヘルス",             icon: "heart.fill",          color: "#E91E63", isDefault: true),
        .init(id: UUID(), name: "セキュリティ",        icon: "lock.shield.fill",   color: "#607D8B", isDefault: true),
        .init(id: UUID(), name: "その他",             icon: "tag.fill",            color: "#95A5A6", isDefault: true),
    ]
}
