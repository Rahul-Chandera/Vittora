import SwiftUI

extension View {
    /// Pointer / trackpad highlight on iPad and macOS (Epic J4).
    @ViewBuilder
    func vittoraPointerHighlight() -> some View {
        #if os(macOS)
        self.onHover { hovering in
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
        #else
        self.hoverEffect(.highlight)
        #endif
    }
}

#if os(macOS)
import AppKit
#endif
