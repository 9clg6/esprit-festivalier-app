import EFDesign
import SwiftUI

@main
struct EspritFestivalierApp: App {
    private let environment = AppEnvironment()

    init() {
        EFFonts.register()
    }

    var body: some Scene {
        WindowGroup {
            RootView(environment: environment)
        }
    }
}
