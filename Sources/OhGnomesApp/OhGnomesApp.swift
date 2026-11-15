import SwiftUI

@main
public struct OhGnomesApp: App {
    @StateObject private var viewModel = HostViewModel()

    public init() {}

    public var body: some Scene {
        WindowGroup {
            HostBroadcastView(viewModel: viewModel)
                .preferredColorScheme(.dark)
        }
        .windowStyle(.hiddenTitleBar)
    }
}
