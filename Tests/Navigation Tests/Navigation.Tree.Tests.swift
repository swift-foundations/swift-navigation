import Navigation
import Testing

/// `Navigation.Tree` is generic, and a suite declared in an extension of a generic type
/// cannot be discovered, so the suite is hosted top-level per the testing skill.
@Suite struct `Navigation Tree Tests` {
    @Suite struct Unit {}
    @Suite struct `Edge Case` {}
    @Suite struct Integration {}

    enum Screen: Sendable, Hashable {
        case inbox
        case message(Int)
        case composer
        case attachments
        case discard
    }

    /// Mints placements so a test reads as a sequence of navigations.
    struct Placer {
        var source = Navigation.Source()

        mutating func callAsFunction(_ screen: Screen) -> Navigation.Destination<Screen> {
            Navigation.Destination(identity: source.mint(), value: screen)
        }
    }

    static let sheet = Navigation.Presentation(mode: .modal, dismissal: .user)
    static let inspector = Navigation.Presentation(mode: .modeless, dismissal: .user)
    static let insistent = Navigation.Presentation(mode: .modal, dismissal: .program)
}

extension `Navigation Tree Tests`.Unit {
    typealias Screen = `Navigation Tree Tests`.Screen
    typealias Placer = `Navigation Tree Tests`.Placer

    @Test func `a new tree shows its root and nothing else`() {
        var place = Placer()
        let inbox = place(.inbox)
        let tree = Navigation.Tree(root: inbox)

        #expect(tree.top == inbox)
        #expect(tree.stack.isEmpty)
        #expect(tree.presentations.isEmpty)
        #expect(tree.depth == 1)
    }

    @Test func `push changes what is showing`() throws {
        var place = Placer()
        var tree = Navigation.Tree(root: place(.inbox))
        let message = place(.message(42))

        try tree.push(message)

        #expect(tree.top == message)
        #expect(tree.destinations.count == 2)
    }

    @Test func `pop returns to the previous destination`() throws {
        var place = Placer()
        let inbox = place(.inbox)
        var tree = Navigation.Tree(root: inbox)
        let message = place(.message(1))
        try tree.push(message)

        let popped = tree.pop()

        #expect(popped == message)
        #expect(tree.top == inbox)
    }

    @Test func `pop stops at the root`() throws {
        var place = Placer()
        let inbox = place(.inbox)
        var tree = Navigation.Tree(root: inbox)
        try tree.push(place(.message(1)))

        _ = tree.pop()

        #expect(tree.pop() == nil)
        #expect(tree.top == inbox)
    }

    @Test func `pop to the root clears the stack`() throws {
        var place = Placer()
        let inbox = place(.inbox)
        var tree = Navigation.Tree(root: inbox)
        try tree.push(place(.message(1)))
        try tree.push(place(.message(2)))

        try tree.pop(to: inbox.identity)

        #expect(tree.top == inbox)
        #expect(tree.stack.isEmpty)
    }

    @Test func `present raises a level over this one`() throws {
        var place = Placer()
        var tree = Navigation.Tree(root: place(.inbox))
        let composer = Navigation.Tree(root: place(.composer))

        try tree.present(composer, as: `Navigation Tree Tests`.sheet)

        #expect(tree.depth == 2)
        #expect(tree.presented(.modal)?.tree == composer)
        #expect(tree.presented(.modal)?.presentation.dismissal == .user)
        #expect(tree.presented(.modeless) == nil)
    }

    @Test func `dismiss removes the presentation and everything below it`() throws {
        var place = Placer()
        var tree = Navigation.Tree(root: place(.inbox))
        var composer = Navigation.Tree(root: place(.composer))
        let attachments = place(.attachments)
        try composer.push(attachments)
        try tree.present(composer, as: `Navigation Tree Tests`.sheet)

        let dismissed = tree.dismiss(.modal)

        #expect(dismissed?.tree.contains(attachments.identity) == true)
        #expect(tree.presented(.modal) == nil)
        #expect(tree.contains(attachments.identity) == false)
        #expect(tree.depth == 1)
    }

    @Test func `the two modes branch independently`() throws {
        var place = Placer()
        var tree = Navigation.Tree(root: place(.inbox))
        let composer = Navigation.Tree(root: place(.composer))
        let inspector = Navigation.Tree(root: place(.attachments))

        try tree.present(composer, as: `Navigation Tree Tests`.sheet)
        try tree.present(inspector, as: `Navigation Tree Tests`.inspector)

        #expect(tree.presentations.count == 2)
        #expect(tree.presented(.modal)?.tree == composer)
        #expect(tree.presented(.modeless)?.tree == inspector)

        tree.dismiss(.modal)

        #expect(tree.presented(.modal) == nil)
        #expect(tree.presented(.modeless)?.tree == inspector)
    }

    @Test func `descend navigates inside a presented level`() throws {
        var place = Placer()
        var tree = Navigation.Tree(root: place(.inbox))
        try tree.present(
            Navigation.Tree(root: place(.composer)),
            as: `Navigation Tree Tests`.sheet
        )
        let attachments = place(.attachments)

        let ran = try tree.descend(.modal) { presented in
            try presented.push(attachments)
        }

        #expect(ran)
        #expect(tree.presented(.modal)?.tree.top == attachments)
        #expect(tree.contains(attachments.identity))
        #expect(tree.depth == 2)
    }

    @Test func `descend reports when nothing stands in the mode`() {
        var place = Placer()
        var tree = Navigation.Tree(root: place(.inbox))

        let ran = tree.descend(.modal) { _ in }

        #expect(!ran)
    }

    @Test func `identities enumerate the whole tree`() throws {
        var place = Placer()
        let inbox = place(.inbox)
        var tree = Navigation.Tree(root: inbox)
        let message = place(.message(1))
        try tree.push(message)
        let composer = place(.composer)
        try tree.present(Navigation.Tree(root: composer), as: `Navigation Tree Tests`.sheet)

        #expect(tree.identities == [inbox.identity, message.identity, composer.identity])
    }

    @Test func `trees are values with structural equality`() throws {
        var place = Placer()
        let root = place(.inbox)
        var left = Navigation.Tree(root: root)
        var right = Navigation.Tree(root: root)

        #expect(left == right)

        try left.push(place(.message(1)))
        #expect(left != right)

        right = left
        _ = left.pop()
        #expect(left != right)
        #expect(right.destinations.count == 2)
    }
}

extension `Navigation Tree Tests`.`Edge Case` {
    typealias Screen = `Navigation Tree Tests`.Screen
    typealias Placer = `Navigation Tree Tests`.Placer

    @Test func `presenting twice in one mode throws and leaves the tree untouched`() throws {
        var place = Placer()
        var tree = Navigation.Tree(root: place(.inbox))
        let composer = Navigation.Tree(root: place(.composer))
        try tree.present(composer, as: `Navigation Tree Tests`.sheet)
        let second = Navigation.Tree(root: place(.discard))

        #expect(throws: Navigation.Error.occupied(.modal)) {
            try tree.present(second, as: `Navigation Tree Tests`.insistent)
        }

        #expect(tree.presentations.count == 1)
        #expect(tree.presented(.modal)?.tree == composer)
    }

    @Test func `pushing an identity already placed deeper in the tree throws`() throws {
        var place = Placer()
        var tree = Navigation.Tree(root: place(.inbox))
        let composer = place(.composer)
        try tree.present(Navigation.Tree(root: composer), as: `Navigation Tree Tests`.sheet)

        #expect(throws: Navigation.Error.duplicate(composer.identity)) {
            try tree.push(composer)
        }

        #expect(tree.stack.isEmpty)
    }

    @Test func `presenting a tree that reuses an identity throws`() throws {
        var place = Placer()
        let inbox = place(.inbox)
        var tree = Navigation.Tree(root: inbox)

        #expect(throws: Navigation.Error.duplicate(inbox.identity)) {
            try tree.present(Navigation.Tree(root: inbox), as: `Navigation Tree Tests`.sheet)
        }

        #expect(tree.presentations.isEmpty)
    }

    @Test func `popping to an identity on a presented level is unknown here`() throws {
        var place = Placer()
        var tree = Navigation.Tree(root: place(.inbox))
        let composer = place(.composer)
        try tree.present(Navigation.Tree(root: composer), as: `Navigation Tree Tests`.sheet)

        #expect(throws: Navigation.Error.unknown(composer.identity)) {
            try tree.pop(to: composer.identity)
        }

        #expect(tree.contains(composer.identity))
    }

    @Test func `dismissing a mode that stands empty reports nothing`() {
        var place = Placer()
        var tree = Navigation.Tree(root: place(.inbox))

        #expect(tree.dismiss(.modal) == nil)
        #expect(tree.dismiss(.modeless) == nil)
    }

    @Test func `pushing beneath a presentation leaves it standing`() throws {
        var place = Placer()
        var tree = Navigation.Tree(root: place(.inbox))
        let composer = Navigation.Tree(root: place(.composer))
        try tree.present(composer, as: `Navigation Tree Tests`.sheet)

        try tree.push(place(.message(7)))

        #expect(tree.presented(.modal)?.tree == composer)
        #expect(tree.top.value == .message(7))
    }

    @Test func `popping beneath a presentation leaves it standing`() throws {
        var place = Placer()
        var tree = Navigation.Tree(root: place(.inbox))
        try tree.push(place(.message(7)))
        let composer = Navigation.Tree(root: place(.composer))
        try tree.present(composer, as: `Navigation Tree Tests`.sheet)

        _ = tree.pop()

        #expect(tree.presented(.modal)?.tree == composer)
        #expect(tree.top.value == .inbox)
    }
}

extension `Navigation Tree Tests`.Integration {
    typealias Screen = `Navigation Tree Tests`.Screen
    typealias Placer = `Navigation Tree Tests`.Placer

    @Test func `a deep link builds state by describing it in order`() throws {
        var place = Placer()

        // What a consumer's parser does: describe the state, in order, from a URL.
        var navigation = Navigation.Tree(root: place(.inbox))
        try navigation.push(place(.message(99)))
        var composer = Navigation.Tree(root: place(.composer))
        try composer.push(place(.attachments))
        try navigation.present(composer, as: `Navigation Tree Tests`.sheet)

        #expect(navigation.depth == 2)
        #expect(navigation.top.value == .message(99))
        #expect(navigation.presented(.modal)?.tree.top.value == .attachments)

        // What a consumer's printer walks: public structure, all the way down.
        let onRoot = navigation.destinations.map(\.value)
        let inSheet = navigation.presented(.modal)?.tree.destinations.map(\.value) ?? []
        #expect(onRoot + inSheet == [.inbox, .message(99), .composer, .attachments])
    }

    @Test func `nesting expresses a presentation raised from a presentation`() throws {
        var place = Placer()
        var navigation = Navigation.Tree(root: place(.inbox))
        try navigation.present(
            Navigation.Tree(root: place(.composer)),
            as: `Navigation Tree Tests`.sheet
        )
        let discard = place(.discard)

        // A confirmation raised by the sheet is presented by the sheet's level,
        // which is what puts it above the sheet rather than beside it.
        try navigation.descend(.modal) { sheet in
            try sheet.present(
                Navigation.Tree(root: discard),
                as: `Navigation Tree Tests`.insistent
            )
        }

        #expect(navigation.depth == 3)
        #expect(navigation.presented(.modal)?.tree.presented(.modal)?.tree.root == discard)
        #expect(
            navigation.presented(.modal)?.tree.presented(.modal)?.presentation.dismissal
                == .program
        )
    }

    @Test func `dismissing a level discards everything nested below it`() throws {
        var place = Placer()
        var navigation = Navigation.Tree(root: place(.inbox))
        try navigation.present(
            Navigation.Tree(root: place(.composer)),
            as: `Navigation Tree Tests`.sheet
        )
        let discard = place(.discard)
        try navigation.descend(.modal) { sheet in
            try sheet.present(
                Navigation.Tree(root: discard),
                as: `Navigation Tree Tests`.insistent
            )
        }

        navigation.dismiss(.modal)

        #expect(navigation.depth == 1)
        #expect(!navigation.contains(discard.identity))
    }

    @Test func `identities stay unique across the whole tree`() throws {
        var place = Placer()
        var navigation = Navigation.Tree(root: place(.inbox))
        try navigation.push(place(.message(1)))
        var composer = Navigation.Tree(root: place(.composer))
        try composer.push(place(.attachments))
        try navigation.present(composer, as: `Navigation Tree Tests`.sheet)
        try navigation.present(
            Navigation.Tree(root: place(.discard)),
            as: `Navigation Tree Tests`.inspector
        )

        let identities = navigation.identities

        #expect(identities.count == 5)
        #expect(Set(identities).count == 5)
        for identity in identities {
            #expect(navigation.contains(identity))
        }
    }
}
