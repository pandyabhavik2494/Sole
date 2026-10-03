import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Sole",
                systemImage: "shoeprints.fill",
                description: Text("Step tracking is coming soon.")
            )
            .navigationTitle("Sole")
        }
    }
}

#Preview {
    ContentView()
}
