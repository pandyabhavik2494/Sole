import SwiftUI

/// The + button's sheet: log weight or tag today.
struct AddSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ContentUnavailableView("Log weight and tag your day", systemImage: "plus.circle", description: Text("Coming next."))
                .navigationTitle("Add")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close", systemImage: "xmark") { dismiss() }
                    }
                }
        }
        .presentationDetents([.medium, .large])
    }
}
