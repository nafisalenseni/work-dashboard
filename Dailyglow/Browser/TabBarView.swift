//
//  TabBarView.swift
//  Dailyglow
//
//  Created by Nafisa Lenseni on 8/29/26.
//

import SwiftUI

struct TabBarView: View {
    var body: some View {
        HStack {

            Spacer()

            BrowserControlsView()
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity)
        .frame(height: 38)
    }
}

#if DEBUG
#Preview("Tab Bar") {
    TabBarView()
        .environment(BrowserSession())
        .frame(width: 760)
}
#endif
