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
        if #available(iOS 17.0, *) {
            self.hoverEffect(.highlight)
        } else {
            self
        }
        #endif
    }
}

#if os(macOS)
import AppKit
#endif
