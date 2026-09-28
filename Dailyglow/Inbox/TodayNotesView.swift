import SwiftUI

/// Keeps the editor mounted while hidden, preserving the document and cursor.
struct TodayNotesView: View {
  @Binding var isExpanded: Bool
  let collapsed: Bool
  let detached: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: collapsed ? 0 : 7) {
      if !collapsed {
        Button {
          isExpanded.toggle()
        } label: {
          HStack(spacing: 8) {
            Image(systemName: "note.text")
            Text("Notes")
            Spacer()
            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
              .font(.system(size: 10, weight: .semibold))
          }
          .font(.system(size: 14))
          .padding(.horizontal, 5)
          .padding(.vertical, 6)
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
      }
      VStack(alignment: .leading, spacing: 6) {
        BlockNoteEditorView(storageKey: "dailyglow.today.blocknote.document", compact: true)
          .accessibilityLabel("Today's notes")
          .frame(minHeight: 200, maxHeight: detached ? .infinity : 200)
      }
      .background(.background, in: RoundedRectangle(cornerRadius: 10))
      .clipShape(RoundedRectangle(cornerRadius: 10))
      .frame(height: collapsed || !isExpanded ? 0 : nil)
      .clipped()
      .opacity(collapsed || !isExpanded ? 0 : 1)
      .allowsHitTesting(!collapsed && isExpanded)
      .accessibilityHidden(collapsed || !isExpanded)
    }
  }
}
