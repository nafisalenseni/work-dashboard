import SwiftUI

struct SidebarSubsectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
    }
}

#if DEBUG
#Preview("Sidebar Subsection Header") {
    SidebarSubsectionHeader(title: "Open")
        .padding()
        .frame(width: 260)
}
#endif
