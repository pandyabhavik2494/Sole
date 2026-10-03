import SwiftUI

struct RecapView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                ContentUnavailableView("Your first recap is on the way", systemImage: "rectangle.stack.fill", description: Text("Every Monday Sole tells the story of your week: activity, heart, body and one thing to try."))
                    .padding(.top, 80)
            }
            .background { GlowBackground() }
            .navigationTitle("Recap")
        }
    }
}
