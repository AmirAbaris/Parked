import SwiftUI

struct ParkingDetailsEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: ParkingDetailsDraft
    let onCancel: () -> Void
    let onSave: (ParkingDetailsDraft) -> Void

    init(
        initialDraft: ParkingDetailsDraft,
        onCancel: @escaping () -> Void,
        onSave: @escaping (ParkingDetailsDraft) -> Void
    ) {
        _draft = State(initialValue: initialDraft)
        self.onCancel = onCancel
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Mesalan B2", text: $draft.floor)
                        .textContentType(.location)
                } header: {
                    Text("Tabaghe")
                }

                Section {
                    TextField("Mesalan Abi", text: $draft.section)
                } header: {
                    Text("Bakhsh")
                }

                Section {
                    TextField("Mesalan C-14", text: $draft.spot)
                } header: {
                    Text("Ja ya sotoon")
                }

                Section {
                    TextField("Mesalan kenare asansor", text: $draft.landmark)
                } header: {
                    Text("Neshone")
                }

                Section {
                    TextField("Har chizi ke komaket mikone", text: $draft.note, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    Text("Yaddasht")
                } footer: {
                    Text("Hame-ye in joz'iyat ekhtiarian.")
                }
            }
            .navigationTitle("Joz'iyat-e park")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Bikhial") {
                        onCancel()
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(draft)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}
