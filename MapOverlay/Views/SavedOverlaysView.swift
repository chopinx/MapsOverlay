import SwiftUI

struct SavedOverlaysView: View {
    @ObservedObject var viewModel: MapOverlayViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.savedOverlays.isEmpty {
                    ContentUnavailableView(
                        "No Saved Overlays",
                        systemImage: "map",
                        description: Text("Import an image, align it on the map, lock it, then save.")
                    )
                } else {
                    List {
                        ForEach(viewModel.savedOverlays) { overlay in
                            Button {
                                viewModel.loadOverlay(overlay)
                                dismiss()
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(overlay.name)
                                            .font(.headline)
                                        Text(overlay.createdAt, style: .date)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Text("\(Int(overlay.opacity * 100))%")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .tint(.primary)
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                viewModel.deleteOverlay(viewModel.savedOverlays[index])
                            }
                        }
                    }
                }
            }
            .navigationTitle("Saved Overlays")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
