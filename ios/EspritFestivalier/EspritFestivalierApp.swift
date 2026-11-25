import EFDesign
import SwiftUI
import UIKit

@main
struct EspritFestivalierApp: App {
    private let environment = AppEnvironment()

    init() {
        EFFonts.register()
        // Large titles in Chivo, like the design system's titles.
        if let large = UIFont(name: "Chivo-Black", size: 34), let inline = UIFont(name: "Chivo-Bold", size: 17) {
            let accent = UIColor(EFColorToken.accent.color)
            UINavigationBar.appearance().largeTitleTextAttributes = [.font: large, .foregroundColor: accent]
            UINavigationBar.appearance().titleTextAttributes = [.font: inline]
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView(environment: environment)
        }
    }
}
