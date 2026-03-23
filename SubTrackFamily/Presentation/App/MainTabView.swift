import SwiftUI

struct MainTabView: View {

    var body: some View {
        TabView {
            Tab("ホーム", systemImage: "house.fill") {
                DashboardView()
            }
            Tab("サブスク", systemImage: "list.bullet.rectangle") {
                SubscriptionListView()
            }
            Tab("契約情報", systemImage: "doc.text.magnifyingglass") {
                ContractListView()
            }
            Tab("ファミリー", systemImage: "person.2.fill") {
                FamilyGroupView()
            }
            Tab("設定", systemImage: "gearshape.fill") {
                SettingsView()
            }
        }
    }
}
