import SwiftUI

struct MainTabView: View {

    var body: some View {
        // Tab(_:systemImage:content:) は iOS 18+ のみ利用可能なため、
        // iOS 17 対応の tabItem モディファイアを使用する
        TabView {
            DashboardView()
                .tabItem {
                    Label("ホーム", systemImage: "house.fill")
                }
            SubscriptionListView()
                .tabItem {
                    Label("サブスク", systemImage: "list.bullet.rectangle")
                }
            ContractListView()
                .tabItem {
                    Label("契約情報", systemImage: "doc.text.magnifyingglass")
                }
            FamilyGroupView()
                .tabItem {
                    Label("ファミリー", systemImage: "person.2.fill")
                }
            SettingsView()
                .tabItem {
                    Label("設定", systemImage: "gearshape.fill")
                }
        }
    }
}
