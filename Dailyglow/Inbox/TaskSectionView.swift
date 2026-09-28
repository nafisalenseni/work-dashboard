import SwiftUI

/// Shared section chrome; callers own task state and supply the header and body.
/// Detached Today scrolls only the body, leaving its header visible.
struct TaskSectionView<Header: View, Content: View>: View {
  let collapsed: Bool
  let accent: Color
  let background: Color
  var scrollsContent = false
  @ViewBuilder var header: () -> Header
  @ViewBuilder var content: () -> Content

  var body: some View {
    VStack(alignment: .leading, spacing: collapsed ? 0 : 7) {
      header()
        .padding(.horizontal, 4)
        .padding(.top, 5)
        .padding(.bottom, 6)
      if scrollsContent {
        ScrollView { content() }
          .frame(height: collapsed ? 0 : nil)
          .clipped()
      } else {
        content()
      }
    }
    .padding(9)
    .background(background, in: RoundedRectangle(cornerRadius: 13))
    .overlay(RoundedRectangle(cornerRadius: 13).stroke(accent.opacity(0.3)))
  }
}
