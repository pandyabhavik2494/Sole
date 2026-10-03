import SwiftUI

/// The + button's sheet: log weight (saved to Apple Health) or tag today (kept in Sole).
struct AddSheet: View {
    enum Mode: String, CaseIterable, Identifiable {
        case weight = "Weight"
        case tag = "Tag today"
        var id: String { rawValue }
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(MetricsEngine.self) private var metrics
    @Environment(Preferences.self) private var preferences

    @State private var mode: Mode
    /// Weight in tenths of the user's unit, so the wheel moves in 0.1 steps.
    @State private var tenths: Int = 0
    @State private var tags: Set<DayTagKind> = []
    @State private var isSaving = false
    @State private var error: String?
    @State private var didLoad = false

    init(mode: Mode? = nil) {
        _mode = State(initialValue: mode ?? .weight)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Picker("What to add", selection: $mode) {
                    ForEach(availableModes) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                switch mode {
                case .weight: weightPicker
                case .tag: tagPicker
                }

                if let error {
                    Label(error, systemImage: "exclamationmark.circle.fill")
                        .font(.footnote)
                        .foregroundStyle(Palette.watch)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Spacer(minLength: 0)

                Button(action: save) {
                    Text(isSaving ? "Saving…" : "Save")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.glassProminent)
                .tint(Palette.accent)
                .disabled(isSaving)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
            .navigationTitle("Add")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onAppear(perform: load)
        .onChange(of: mode) { error = nil }
    }

    private var availableModes: [Mode] {
        preferences.hidesWeight ? [.tag] : Mode.allCases
    }

    // MARK: Weight

    private var unit: String { metrics.units.symbol(for: .weight) }

    private var weightPicker: some View {
        VStack(spacing: 4) {
            Picker("Weight", selection: $tenths) {
                ForEach(weightRange, id: \.self) { value in
                    Text("\(Double(value) / 10, format: .number.precision(.fractionLength(1))) \(unit)")
                        .monospacedDigit()
                        .tag(value)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 160)
            Text("Saved to Apple Health")
                .font(.footnote)
                .foregroundStyle(Palette.muted)
        }
    }

    /// 20–250 kg in the user's unit.
    private var weightRange: ClosedRange<Int> {
        let low = Int((metrics.units.display(20, for: .weight) * 10).rounded())
        let high = Int((metrics.units.display(250, for: .weight) * 10).rounded())
        return low...high
    }

    // MARK: Tags

    private var tagPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Anything going on today?")
                .font(.footnote.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(Palette.muted)
            FlowLayout(spacing: 8) {
                ForEach(DayTagKind.allCases) { kind in
                    let isOn = tags.contains(kind)
                    Button {
                        if isOn { tags.remove(kind) } else { tags.insert(kind) }
                    } label: {
                        Label(kind.title, systemImage: kind.symbol)
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .foregroundStyle(isOn ? Palette.onAccent : Palette.ink)
                            .background(isOn ? Palette.accent : Palette.surface, in: Capsule())
                            .overlay(Capsule().stroke(Palette.line, lineWidth: isOn ? 0 : 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                }
            }
            Text("Tags show on your charts. Sick and travel days are left out of your usual ranges.")
                .font(.footnote)
                .foregroundStyle(Palette.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Actions

    private func load() {
        guard !didLoad else { return }
        didLoad = true
        if preferences.hidesWeight { mode = .tag }
        let kilograms = metrics.latestWeight ?? 70
        tenths = Int((metrics.units.display(kilograms, for: .weight) * 10).rounded())
        tags = metrics.tags[metrics.insights.day] ?? []
    }

    private func save() {
        error = nil
        switch mode {
        case .tag:
            metrics.setTags(tags, on: DayKey(.now, calendar: metrics.calendar))
            dismiss()
        case .weight:
            isSaving = true
            let kilograms = metrics.units.canonical(Double(tenths) / 10, for: .weight)
            Task {
                do {
                    try await metrics.logWeight(kilograms: kilograms)
                    dismiss()
                } catch {
                    self.error = error.localizedDescription
                }
                isSaving = false
            }
        }
    }
}

/// Lays children out in rows, wrapping to the next line when full.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = rows(for: subviews, width: proposal.width ?? .infinity)
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in rows(for: subviews, width: bounds.width) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func rows(for subviews: Subviews, width: CGFloat) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if needed > width, !current.indices.isEmpty {
                rows.append(current)
                current = Row()
            }
            current.width = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
            current.indices.append(index)
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}
