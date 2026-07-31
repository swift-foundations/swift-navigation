extension Navigation {
    /// A level shown over another, together with how it is shown.
    ///
    /// The pair is inseparable on purpose. A presented level without its
    /// presentation cannot say whether the level beneath it still accepts input,
    /// or whether the person may dismiss it — and both of those decide what the
    /// runtime is allowed to do when a dismissal arrives.
    ///
    /// ```swift
    /// if let sheet = navigation.presented(.modal) {
    ///     sheet.presentation.dismissal    // .user — an unsolicited dismissal is legal
    ///     sheet.tree.top.value            // what the sheet is currently showing
    /// }
    /// ```
    public struct Presented<Value> {
        /// How the level is shown, and who may end it.
        public let presentation: Navigation.Presentation

        /// The level being shown.
        public internal(set) var tree: Navigation.Tree<Value>

        /// Pairs a level with the presentation showing it.
        ///
        /// - Parameters:
        ///   - presentation: How the level is shown.
        ///   - tree: The level being shown.
        public init(presentation: Navigation.Presentation, tree: Navigation.Tree<Value>) {
            self.presentation = presentation
            self.tree = tree
        }
    }
}

// MARK: - Conditional Conformances

extension Navigation.Presented: Sendable where Value: Sendable {}
extension Navigation.Presented: Equatable where Value: Equatable {}
extension Navigation.Presented: Hashable where Value: Hashable {}
