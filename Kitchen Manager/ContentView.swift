import SwiftUI

struct ContentView: View {
    @Environment(KitchenStore.self) private var store
    @State private var selectedTab: AppTab = .home

    var body: some View {
        ZStack(alignment: .top) {
            TabView(selection: $selectedTab) {
                Tab(AppTab.home.shortTitle, systemImage: AppTab.home.symbolName, value: .home) {
                    HomePage { tab in selectedTab = tab }
                }

                Tab(AppTab.mealPlan.shortTitle, systemImage: AppTab.mealPlan.symbolName, value: .mealPlan) {
                    MealPlanPage()
                }

                Tab(AppTab.shopping.shortTitle, systemImage: AppTab.shopping.symbolName, value: .shopping) {
                    ShoppingPage()
                }

                Tab(AppTab.inventory.shortTitle, systemImage: AppTab.inventory.symbolName, value: .inventory) {
                    InventoryPage()
                }

                Tab(AppTab.budget.shortTitle, systemImage: AppTab.budget.symbolName, value: .budget) {
                    BudgetPage()
                }
            }

            if let message = store.toastMessage {
                ToastView(message: message)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 8)
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(KitchenStore())
}
