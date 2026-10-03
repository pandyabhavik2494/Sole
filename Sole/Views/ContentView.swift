import SwiftUI

struct ContentView: View {
    @Environment(StepEngine.self) private var engine

    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                Text(Format.steps(engine.today.steps))
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text("steps today")
                    .foregroundStyle(Palette.muted)
            }
            .navigationTitle("Sole")
        }
    }
}
