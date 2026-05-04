import SwiftUI

struct ContentView: View {
    @EnvironmentObject var manager: WorkoutManager

    
    init() {
        // Dark tab bar appearance
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .black
        appearance.shadowColor = UIColor.white.withAlphaComponent(0.05)
        
        // Explicitly set selected states to white to avoid blue default
        let selectedColor = UIColor.white
        let unselectedColor = UIColor.gray
        
        appearance.stackedLayoutAppearance.selected.iconColor = selectedColor
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: selectedColor]
        
        appearance.stackedLayoutAppearance.normal.iconColor = unselectedColor
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: unselectedColor]
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
    
    var body: some View {
        ZStack {
            TabView(selection: $manager.currentView) {
                CalendarView()
                    .tabItem {
                        Image(systemName: "calendar")
                        Text("训练计划")
                    }
                    .tag(AppView.calendar)
                
                TimerView()
                    .tabItem {
                        Image(systemName: "stopwatch")
                        Text("计时器")
                    }
                    .tag(AppView.timer)
                
                SettingsView()
                    .tabItem {
                        Image(systemName: "gearshape")
                        Text("设置")
                    }
                    .tag(AppView.settings)
            }
            .sheet(isPresented: Binding(
                get: { manager.showAddModal || manager.showEditModal },
                set: { newValue in
                    if !newValue {
                        manager.showAddModal = false
                        manager.showEditModal = false
                        manager.editingExercise = nil
                    }
                }
            )) {
                AddExerciseView()
                    .environmentObject(manager)
            }

        }
    }
}
