import SwiftUI

@main
struct AnclaApp: App {
  @State private var viewModel = AppViewModel()
  @State private var showsStartupSplash = true
  @State private var hasHandledStartupSplash = false

  var body: some Scene {
    WindowGroup {
      ZStack {
        ContentView(viewModel: viewModel)

        if showsStartupSplash && !viewModel.shouldShowLockedScreen {
          StartupSplashView()
            .transition(.opacity)
            .zIndex(1)
        }
      }
      .task {
        guard !hasHandledStartupSplash else {
          return
        }

        hasHandledStartupSplash = true

        guard !viewModel.shouldShowLockedScreen else {
          showsStartupSplash = false
          return
        }

        try? await Task.sleep(nanoseconds: 900_000_000)
        guard !Task.isCancelled else {
          return
        }

        withAnimation(.easeOut(duration: 0.24)) {
          showsStartupSplash = false
        }
      }
      .onChange(of: viewModel.shouldShowLockedScreen) { _, isShowingLockedScreen in
        if isShowingLockedScreen {
          showsStartupSplash = false
        }
      }
    }
  }
}
