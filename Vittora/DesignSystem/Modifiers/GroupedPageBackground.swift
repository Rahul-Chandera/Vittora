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
    /// iPad fills a List row it treats as selected — the NavigationLink just
    /// tapped, while its screen pushes in and until it pops — with the List's
    /// tint. Ours was `.primary` on the lists the accessibility sweep tinted
    /// and the AA-dark accent everywhere else, so the row went black or dark
    /// green under black text. Put this on the List itself, straight after its
    /// closing brace (inside any .toolbar or .sheet, which keep their own
    /// tint), and wrap the List's content in `vListContentTint` so the rows'
    /// controls keep the tint they had. A tint on a row does not reach the fill.
    @ViewBuilder
    func vListSelectionTint() -> some View {
        #if os(iOS)
        tint(VColors.rowSelection)
        #else
        self
        #endif
    }

    /// The tint a List's rows had before `vListSelectionTint` lightened the
    /// List's own: apply it to a Group wrapping the List's content.
    @ViewBuilder
    func vListContentTint(_ tint: some ShapeStyle = VColors.primaryOnSurface) -> some View {
        #if os(iOS)
        self.tint(tint)
        #else
        self
        #endif
    }
}

extension View {
    /// A text field that types where its placeholder sits.
    ///
    /// A macOS grouped Form lays every TextField out as a labelled row and
    /// right-aligns the value, even with an empty label — but draws the prompt
    /// at the left. So "Goal name" sat on the left and the caret and typed text
    /// on the right. With the label hidden the field fills its row and keeps one
    /// alignment for prompt and text. Give such fields an explicit `prompt:`:
    /// the hidden title is no longer shown as a placeholder.
    ///
    /// The prompt is drawn leading even in a field aligned trailing (the
    /// amount fields, trailing on iOS), so macOS aligns every field leading.
    /// Applied innermost, so it wins over a later `.multilineTextAlignment`.
    /// `inline` is for a value field beside its own label ("Target  0"),
    /// trailing on iOS: on macOS it gets a bordered box, or its "0" prompt
    /// floats mid-row with nothing to say it is a field. No-op on iOS.
    @ViewBuilder
    func vFormField(inline: Bool = false) -> some View {
        #if os(macOS)
        if inline {
            labelsHidden()
                .multilineTextAlignment(.leading)
                .textFieldStyle(.roundedBorder)
        } else {
            labelsHidden()
                .multilineTextAlignment(.leading)
        }
        #else
        self
        #endif
    }
}
