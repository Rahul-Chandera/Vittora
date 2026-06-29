import SwiftUI

/// Standard right-click / long-press actions for primary list rows (J4 / MULTIPLATFORM-5).
struct VittoraRowContextMenuActions {
    var onEdit: (() -> Void)?
    var onDuplicate: (() -> Void)?
    var onArchive: (() -> Void)?
    var onDelete: (() -> Void)?

    static var empty: VittoraRowContextMenuActions { .init() }
}

extension View {
    @ViewBuilder
    func vittoraRowContextMenu(_ actions: VittoraRowContextMenuActions) -> some View {
        let hasMenu = actions.onEdit != nil
            || actions.onDuplicate != nil
            || actions.onArchive != nil
            || actions.onDelete != nil

        if hasMenu {
            contextMenu {
                if let onEdit = actions.onEdit {
                    Button(action: onEdit) {
                        Label(String(localized: "Edit"), systemImage: "pencil")
                    }
                }
                if let onDuplicate = actions.onDuplicate {
                    Button(action: onDuplicate) {
                        Label(String(localized: "Duplicate"), systemImage: "plus.square.on.square")
                    }
                }
                if let onArchive = actions.onArchive {
                    Button(action: onArchive) {
                        Label(String(localized: "Archive"), systemImage: "archivebox")
                    }
                }
                if let onDelete = actions.onDelete {
                    Button(role: .destructive, action: onDelete) {
                        Label(String(localized: "Delete"), systemImage: "trash")
                    }
                }
            }
        } else {
            self
        }
    }
}
