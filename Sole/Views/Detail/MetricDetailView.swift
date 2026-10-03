import SwiftUI

struct MetricDetailView: View {
    let metric: Metric

    var body: some View {
        ContentUnavailableView(metric.title, systemImage: metric.symbol, description: Text("Details are on the way."))
            .navigationTitle(metric.title)
    }
}
