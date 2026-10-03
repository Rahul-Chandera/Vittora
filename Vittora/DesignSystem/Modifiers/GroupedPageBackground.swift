import SwiftUI

extension View {
    /// Makes the grouped page colour visible behind `List` and `Form` content.
    ///
    /// A List or Form paints its own system background, which covers whatever
    /// the screen drew behind it. On iOS that default is `systemGroupedBackground`
    /// — the same colour as `VColors.groupedBackground` — so screens looked right
    /// by coincidence rather than by intent.
    ///
    /// On macOS 26 the default is `textBackgroundColor`, which now resolves to
    /// #FFFFFF, the same value as `windowBackgroundColor` and
    /// `controlBackgroundColor`. Cards are white too, so every List screen
    /// flattened into one undifferentiated white field: the page colour was
    /// being drawn, then painted straight over.
    ///
    /// Applied at the navigation roots rather than on each of the 36 List and
    /// Form screens. `scrollContentBackground` travels down the environment to
    /// descendant scrollable views, so the roots cover the whole tree — including
    /// sheets, which inherit the presenter's environment.
    func groupedPageBackground() -> some View {
        scrollContentBackground(.hidden)
            .background(VColors.groupedBackground)
    }
}

extension View {
    /// Explicit row background for a `List` or `Form`.
    ///
    /// iPadOS 27 fills a tapped row with the list's tint while the next screen
    /// slides in. Ours is `.primary` on the lists the accessibility sweep tinted
    /// (black in light mode) and the AA-dark accent everywhere else, so the row
    /// flashed black. With the background set explicitly the system keeps its
    /// light grey tap highlight, as in Apple's own Settings. The colour is the
    /// one iOS paints by default, so nothing else changes — OLED included.
    ///
    /// Apply it to the List or Form itself; on a NavigationStack it does not
    /// reach the lists inside. A row's own `listRowBackground` still wins.
    @ViewBuilder
    func vListRowBackground() -> some View {
        #if os(iOS)
        listRowBackground(Color(uiColor: .secondarySystemGroupedBackground))
        #else
        self
        #endif
    }
}
