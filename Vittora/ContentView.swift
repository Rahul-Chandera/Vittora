//
//  ContentView.swift
//  Vittora
//
//  Created by Rahul on 12/04/26.
//

import SwiftUI

struct ContentView: View {
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    var body: some View {
        #if os(macOS)
        SidebarNavigation()
        #else
        if horizontalSizeClass == .regular {
            SidebarNavigation() // iPad
        } else {
            AppTabView() // iPhone
        }
        #endif
    }
}

#Preview {
    ContentView()
        .environment(AppState())
        .environment(Router())
}
