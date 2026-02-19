import SwiftUI

struct SavedPinsView: View {
    @ObservedObject var viewModel: MapOverlayViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showClearAllConfirmation = false
    var onPinSelected: (SavedPin) -> Void

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.savedPins.isEmpty {
                    ContentUnavailableView(
                        "No Saved Pins",
                        systemImage: "mappin.slash",
                        description: Text("Search for places to add pins to the map.")
                    )
                } else {
                    List {
                        ForEach(viewModel.savedPins) { pin in
                            Button {
                                onPinSelected(pin)
                                dismiss()
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(pin.name)
                                        .font(.body)
                                        .foregroundColor(.primary)
                                    Text(String(format: "%.4f, %.4f", pin.latitude, pin.longitude))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                        .onDelete { indexSet in
                            indexSet.forEach { viewModel.deletePin(viewModel.savedPins[$0]) }
                        }
                    }
                }
            }
            .navigationTitle("Saved Pins")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                if !viewModel.savedPins.isEmpty {
                    ToolbarItem(placement: .destructiveAction) {
                        Button("Clear All", role: .destructive) {
                            showClearAllConfirmation = true
                        }
                    }
                }
            }
            .confirmationDialog("Clear all pins?", isPresented: $showClearAllConfirmation, titleVisibility: .visible) {
                Button("Clear All", role: .destructive) {
                    viewModel.clearAllPins()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will remove all saved pins. This action cannot be undone.")
            }
        }
    }
}
