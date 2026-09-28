import SwiftUI

struct PanelStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.white)
            .clipShape(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .shadow(
                color: .black.opacity(0.15),
                radius: 12,
                x: 0,
                y: 4
            )
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
            .padding(.top, 2)
    }
}

extension View {
    func panelStyle() -> some View {
        modifier(PanelStyle())
    }
}
