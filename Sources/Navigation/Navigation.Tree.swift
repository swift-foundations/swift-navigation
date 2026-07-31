extension Navigation {
    /// Navigation state: one level of destinations, and the levels presented over it.
    ///
    /// A level is a stack — a destination to start from, and whatever has been
    /// pushed above it — together with the trees that level presents. Because a
    /// presented tree is a level in its own right, and presents in turn,
    /// navigation state nests: it is a tree of levels, not a flat list of
    /// screens, which is what lets a sheet own a stack of its own without the
    /// two stacks contaminating each other.
    ///
    /// ```swift
    /// var source = Navigation.Identity.Source()
    /// func place(_ screen: Screen) -> Navigation.Destination<Screen> {
    ///     Navigation.Destination(identity: source.mint(), value: screen)
    /// }
    ///
    /// var navigation = Navigation.Tree(root: place(.inbox))
    /// try navigation.push(place(.message(42)))
    ///
    /// var composer = Navigation.Tree(root: place(.composer))
    /// try composer.push(place(.attachments))
    /// try navigation.present(composer, as: .init(mode: .modal, dismissal: .user))
    ///
    /// navigation.top.value                     // .message(42) — the inbox stack is untouched
    /// navigation.presented(.modal)?.tree.top.value   // .attachments
    /// navigation.depth                         // 2
    /// ```
    ///
    /// ## Two invariants
    ///
    /// **Presentations belong to the level, not to a destination in it.** A
    /// sheet raised while a stack is showing stands over the whole stack, and
    /// pushing or popping beneath it does not disturb it — which is what a
    /// person sees, and so what the state records. This is also what keeps the
    /// model free of an identity-keyed side table.
    ///
    /// **At most one presentation per mode.** A level may present one modal
    /// thing and one modeless thing at once. A second modal presentation from
    /// the same level is ambiguous about which one holds attention, and the
    /// unambiguous spelling already exists — the presented tree presents it.
    /// Branching by mode is what keeps this state a tree rather than a chain.
    ///
    /// ## Identity
    ///
    /// Identities are unique across a whole tree, not merely within a level, so
    /// ``contains(_:)`` and ``pop(to:)`` mean the same thing at any depth. The
    /// operations here enforce that; mint every placement from one
    /// ``Navigation/Identity/Source`` and it holds by construction.
    public struct Tree<Value> {
        /// The destination this level starts from.
        public private(set) var root: Navigation.Destination<Value>

        /// Destinations pushed above ``root``, bottom first.
        public private(set) var stack: Navigation.Stack<Value>

        /// The trees this level presents; at most one per presentation mode.
        public private(set) var presentations: [Navigation.Presented<Value>]

        /// Creates a level showing `root`, with nothing pushed and nothing presented.
        ///
        /// - Parameter root: The destination the level starts from.
        public init(root: Navigation.Destination<Value>) {
            self.root = root
            self.stack = Navigation.Stack()
            self.presentations = []
        }
    }
}

// MARK: - Inspection

extension Navigation.Tree {
    /// The destination showing on this level.
    ///
    /// Total: a level always has a root, so there is always something showing.
    public var top: Navigation.Destination<Value> {
        stack.top ?? root
    }

    /// Every destination on this level, bottom first.
    public var destinations: [Navigation.Destination<Value>] {
        [root] + Array(stack)
    }

    /// Every identity in this tree, this level first, then presented levels in
    /// presentation order.
    public var identities: [Navigation.Identity] {
        var result = destinations.map(\.identity)
        for presented in presentations {
            result.append(contentsOf: presented.tree.identities)
        }
        return result
    }

    /// How many levels deep this tree runs, counting this one.
    public var depth: Int {
        1 + (presentations.map(\.tree.depth).max() ?? 0)
    }

    /// Reports whether `identity` names a destination anywhere in this tree.
    ///
    /// - Parameter identity: The identity to look for.
    public func contains(_ identity: Navigation.Identity) -> Bool {
        if root.identity == identity { return true }
        if stack.contains(identity) { return true }
        for presented in presentations where presented.tree.contains(identity) {
            return true
        }
        return false
    }

    /// The presentation standing in `mode`, if there is one.
    ///
    /// - Parameter mode: The mode to look up.
    public func presented(_ mode: Navigation.Presentation.Mode) -> Navigation.Presented<Value>? {
        presentations.first { $0.presentation.mode == mode }
    }

    /// The offset of the presentation standing in `mode`.
    func slot(_ mode: Navigation.Presentation.Mode) -> Int? {
        presentations.firstIndex { $0.presentation.mode == mode }
    }
}

// MARK: - Stack

extension Navigation.Tree {
    /// Pushes `destination` onto this level.
    ///
    /// Presentations standing over this level are untouched: a sheet raised
    /// while the stack was showing stands over the whole stack, so pushing
    /// beneath it changes what is behind it and nothing more.
    ///
    /// - Parameter destination: The destination to push.
    /// - Throws: ``Navigation/Error/duplicate(_:)`` when the identity is already
    ///   placed anywhere in this tree.
    public mutating func push(
        _ destination: Navigation.Destination<Value>
    ) throws(Navigation.Error) {
        guard !contains(destination.identity) else {
            throw Navigation.Error.duplicate(destination.identity)
        }
        try stack.push(destination)
    }

    /// Removes and returns the destination showing on this level, unless it is
    /// the root.
    ///
    /// - Returns: The destination removed, or `nil` when only the root remains.
    public mutating func pop() -> Navigation.Destination<Value>? {
        stack.pop()
    }

    /// Removes destinations from this level until `identity` is showing.
    ///
    /// - Parameter identity: A destination on this level, root included.
    /// - Throws: ``Navigation/Error/unknown(_:)`` when `identity` names nothing
    ///   on this level; the tree is left untouched. An identity on a *presented*
    ///   level is unknown here — pop it on the level that holds it.
    public mutating func pop(to identity: Navigation.Identity) throws(Navigation.Error) {
        if identity == root.identity {
            stack = Navigation.Stack()
            return
        }
        try stack.pop(to: identity)
    }
}

// MARK: - Presentation

extension Navigation.Tree {
    /// Presents `tree` over this level.
    ///
    /// - Parameters:
    ///   - tree: The level to present, with whatever it already holds.
    ///   - presentation: How it is shown, and who may end it.
    /// - Throws: ``Navigation/Error/occupied(_:)`` when a presentation of the
    ///   same mode already stands, or ``Navigation/Error/duplicate(_:)`` when
    ///   `tree` carries an identity already placed in this tree. The tree is
    ///   left untouched either way.
    public mutating func present(
        _ tree: Navigation.Tree<Value>,
        as presentation: Navigation.Presentation
    ) throws(Navigation.Error) {
        guard slot(presentation.mode) == nil else {
            throw Navigation.Error.occupied(presentation.mode)
        }
        for identity in tree.identities where contains(identity) {
            throw Navigation.Error.duplicate(identity)
        }
        presentations.append(
            Navigation.Presented(presentation: presentation, tree: tree)
        )
    }

    /// Ends the presentation standing in `mode`.
    ///
    /// Everything below the dismissed presentation goes with it, which is the
    /// point: a dismissed sheet takes its own stack and its own presentations
    /// away rather than orphaning them.
    ///
    /// - Parameter mode: The mode to dismiss.
    /// - Returns: What was dismissed, or `nil` when nothing stood in `mode`.
    @discardableResult
    public mutating func dismiss(
        _ mode: Navigation.Presentation.Mode
    ) -> Navigation.Presented<Value>? {
        guard let index = slot(mode) else { return nil }
        return presentations.remove(at: index)
    }

    /// Applies `body` to the tree presented in `mode`.
    ///
    /// Navigating inside a presented level — pushing within a sheet, dismissing
    /// something the sheet itself raised — goes through here, so the enclosing
    /// tree stays the single owner of its structure.
    ///
    /// - Parameters:
    ///   - mode: The mode whose presented tree to descend into.
    ///   - body: Applied to that tree in place. Its thrown type propagates, so
    ///     a navigation inside a presented level reports its own failures
    ///     rather than swallowing them at the boundary.
    /// - Returns: `true` when a presentation stood in `mode` and `body` ran.
    @discardableResult
    public mutating func descend<Failure: Swift.Error>(
        _ mode: Navigation.Presentation.Mode,
        _ body: (inout Navigation.Tree<Value>) throws(Failure) -> Void
    ) throws(Failure) -> Bool {
        guard let index = slot(mode) else { return false }
        try body(&presentations[index].tree)
        return true
    }
}

// MARK: - Conditional Conformances

extension Navigation.Tree: Sendable where Value: Sendable {}
extension Navigation.Tree: Equatable where Value: Equatable {}
extension Navigation.Tree: Hashable where Value: Hashable {}
