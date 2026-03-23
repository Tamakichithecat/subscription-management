import Foundation
import Supabase

/// Supabase クライアントのシングルトン
final class SupabaseClientProvider: @unchecked Sendable {

    static let shared = SupabaseClientProvider()

    let client: SupabaseClient

    private init() {
        guard
            let urlString = ProcessInfo.processInfo.environment["SUPABASE_URL"],
            !urlString.isEmpty,
            let url = URL(string: urlString),
            let anonKey = ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"],
            !anonKey.isEmpty
        else {
            // 開発中: 未設定の場合はダミー値で初期化（実機・シミュレーター起動時にクラッシュ回避）
            #if DEBUG
            client = SupabaseClient(
                supabaseURL: URL(string: "https://placeholder.supabase.co")!,
                supabaseKey: "placeholder-key"
            )
            return
            #else
            fatalError("SUPABASE_URL / SUPABASE_ANON_KEY が設定されていません。Scheme の環境変数を確認してください。")
            #endif
        }
        client = SupabaseClient(supabaseURL: url, supabaseKey: anonKey)
    }
}
