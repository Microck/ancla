import SwiftUI

@main
struct AnclaApp: App {
  @State private var viewModel = AppViewModel()

  var body: some Scene {
    WindowGroup {
      ContentView(viewModel: viewModel)
    }
  }
}
