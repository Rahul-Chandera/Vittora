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
