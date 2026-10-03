import SwiftUI

struct TrendsView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                ContentUnavailableView("Trends are on the way", systemImage: "chart.line.uptrend.xyaxis", description: Text("Once Sole has read your Health history, this tab groups every metric by what's getting better, steady or changing."))
                    .padding(.top, 80)
            }
            .background { GlowBackground() }
            .navigationTitle("Trends")
        }
    }
}
