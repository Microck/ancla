import SwiftUI

struct ModeEditorView: View {
  @Bindable var viewModel: AppViewModel
  let isEditingMode: Bool
  let onChooseSelection: () -> Void
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      VStack(alignment: .leading, spacing: 18) {
        Text(isEditingMode ? "Edit mode" : "New mode")
          .font(.ancla(24, weight: .semibold))
          .foregroundStyle(Color(red: 0.06, green: 0.09, blue: 0.16))

        VStack(alignment: .leading, spacing: 8) {
          Text("Name")
            .font(.ancla(13, weight: .medium))
            .foregroundStyle(Color(red: 0.43, green: 0.5, blue: 0.58))

          TextField("Work block", text: $viewModel.draftModeName)
            .textInputAutocapitalization(.words)
            .padding(.horizontal, 14)
            .frame(height: 48)
            .background(
              Color(red: 0.95, green: 0.97, blue: 0.99),
              in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
        }

        VStack(alignment: .leading, spacing: 8) {
          Text("Targets")
            .font(.ancla(13, weight: .medium))
            .foregroundStyle(Color(red: 0.43, green: 0.5, blue: 0.58))

          Button {
            onChooseSelection()
          } label: {
            HStack {
              Text("Choose apps and sites")
              Spacer()
              Text(viewModel.selectionSummary(for: viewModel.draftSelection))
                .font(.ancla(12, weight: .medium))
                .foregroundStyle(Color(red: 0.43, green: 0.5, blue: 0.58))
            }
            .font(.ancla(14))
            .foregroundStyle(Color(red: 0.06, green: 0.09, blue: 0.16))
            .padding(.horizontal, 14)
            .frame(height: 48)
            .background(
              Color(red: 0.95, green: 0.97, blue: 0.99),
              in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
          }
          .buttonStyle(.plain)

          if !viewModel.canSaveDraftMode {
            Text("Choose at least one app, category, or domain.")
              .font(.ancla(12, weight: .medium))
              .foregroundStyle(Color(red: 0.66, green: 0.11, blue: 0.15))
          }
        }

        Toggle(isOn: $viewModel.draftModeShouldBeDefault) {
          Text("Default mode")
            .font(.ancla(14))
            .foregroundStyle(Color(red: 0.06, green: 0.09, blue: 0.16))
        }
        .tint(Color(red: 0.06, green: 0.09, blue: 0.16))

        Spacer()
      }
      .padding(20)
      .background(Color(red: 0.98, green: 0.98, blue: 0.99))
      .navigationTitle("")
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button("Cancel") {
            dismiss()
          }
        }

        ToolbarItem(placement: .topBarTrailing) {
          Button("Save") {
            Task {
              await viewModel.saveMode()
              if viewModel.lastError == nil {
                dismiss()
              }
            }
          }
          .fontWeight(.semibold)
          .disabled(!viewModel.canSaveDraftMode || viewModel.isBusy)
        }
      }
    }
    .presentationDetents([.medium])
  }
}
