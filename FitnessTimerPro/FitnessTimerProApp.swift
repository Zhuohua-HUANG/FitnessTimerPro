import SwiftUI

@main
struct FitnessTimerProApp: App {
    @StateObject var manager = WorkoutManager()

    init() {
        print("DEBUG: App Launch - Screen Width = \(UIScreen.main.bounds.width)")
        
        // Register defaults
        UserDefaults.standard.register(defaults: [
            "isAICreatorEnabled": true
        ])
        
        // Trigger Network Permission Prompt (China region requirement)
        triggerNetworkPermission()
        
    }

    private func triggerNetworkPermission() {
        guard let url = URL(string: "https://www.apple.com") else { return }
        let task = URLSession.shared.dataTask(with: url) { _, _, _ in }
        task.resume()
    }

    @Environment(\.scenePhase) var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(manager)
                .preferredColorScheme(.dark) // Force Dark Mode
        }
    }
}

