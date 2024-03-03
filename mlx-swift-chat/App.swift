//
// Copyright (c) Vatsal Manot
//

import MLXLLM
import SwiftUIX

@main
struct App: SwiftUI.App {
    @StateObject var runner = LLMRunner()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .environmentObject(runner)
    }
}
