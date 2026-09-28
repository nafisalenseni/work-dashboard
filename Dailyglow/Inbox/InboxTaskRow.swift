import SwiftUI

struct InboxTaskRow: View {
  let title: String
  let completed: Bool
  let toggle: () -> Void
  let remove: () -> Void
  let save: (String) async -> Bool
  @State private var hovering = false
  @State private var editing = false
  @State private var draft = ""
  @State private var saving = false
  @FocusState private var focused: Bool
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    HStack(alignment: .top, spacing: 10) {
      Button(action: toggle) {
        Image(systemName: completed ? "checkmark.square.fill" : "square")
          .font(.system(size: 19))
          .foregroundStyle(completed ? Color(red: 0.60, green: 0.46, blue: 0.10) : Color.primary)
      }
      .buttonStyle(.plain)
      .accessibilityLabel(completed ? "Mark incomplete" : "Complete task")
      .accessibilityValue(title)
      if editing {
        TextField("Task name", text: $draft, axis: .vertical)
          .textFieldStyle(.plain)
          .focused($focused)
          .disabled(saving)
          .onSubmit {
            let value = draft.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty else { return }
            saving = true
            Task {
              if await save(value) { editing = false }
              saving = false
            }
          }
          .onExitCommand { editing = false }
      } else {
      Text(title)
        .font(.system(size: 14))
        .lineLimit(2)
        .truncationMode(.tail)
        .help(title)
        .strikethrough(completed)
        .foregroundStyle(
          completed ? Color.secondary : (colorScheme == .dark ? Color.white : Color.black)
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
          draft = title
          editing = true
          focused = true
        }
      }
      Button(action: remove) { Image(systemName: "xmark").font(.system(size: 11)) }
        .buttonStyle(.plain)
        .help("Delete task")
        .accessibilityLabel("Delete task")
        .opacity(hovering && !editing ? 1 : 0)
        .allowsHitTesting(hovering && !editing)
    }
    .onHover { hovering = $0 }
    .padding(13)
    .background(.background, in: RoundedRectangle(cornerRadius: 9))
    .contentShape(RoundedRectangle(cornerRadius: 9))
  }
}

