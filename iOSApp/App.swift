import SwiftUI

@main
struct AegisApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("Aegis").font(.largeTitle).bold()
            Text("SpriteKit + SwiftUI • XcodeGen • SPM")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .padding()
    }
}
