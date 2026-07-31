# swift-navigation

![Development Status](https://img.shields.io/badge/status-active--development-blue.svg)

Tree-based navigation state — levels of identified destinations, composed through presentations.
Foundation-free, shell-independent, and a value all the way down.

---

## Key Features

- **Nested, not flat** — a presented level is a level in its own right, with its own stack and its
  own presentations. A sheet owns a stack without contaminating the stack beneath it.
- **Presentations belong to the level** — a sheet raised while a stack is showing stands over the
  whole stack, so pushing or popping beneath it leaves it standing. That is what a person sees, so
  it is what the state records.
- **One presentation per mode** — a level may present one modal thing and one modeless thing at
  once. A second modal presentation nests inside the first, which is where it renders anyway.
- **Identities are unique tree-wide** — `contains(_:)` and `pop(to:)` mean the same thing at any
  depth, and the operations enforce it rather than trusting the caller.
- **Nothing is orphaned** — dismissing a presentation takes its stack and its own presentations
  with it, and hands them back so the caller can decide what to keep.
- **A value throughout** — `Equatable`, `Hashable`, and `Sendable` exactly when your destination
  value is. Drop it into observable feature state; there is no runtime behind it.

---

## Quick Start

```swift
import Navigation

enum Screen: Hashable, Sendable {
    case inbox, message(Int), composer, attachments
}

var source = Navigation.Identity.Source()
func place(_ screen: Screen) -> Navigation.Destination<Screen> {
    Navigation.Destination(identity: source.mint(), value: screen)
}

var navigation = Navigation.Tree(root: place(.inbox))
try navigation.push(place(.message(42)))

// A sheet with a stack of its own.
var composer = Navigation.Tree(root: place(.composer))
try composer.push(place(.attachments))
try navigation.present(composer, as: .init(mode: .modal, dismissal: .user))

navigation.top.value                            // .message(42) — the inbox stack is untouched
navigation.presented(.modal)?.tree.top.value    // .attachments
navigation.depth                                // 2

// Navigate inside the sheet.
navigation.descend(.modal) { sheet in
    _ = sheet.pop()
}

// Dismissing takes everything below it.
navigation.dismiss(.modal)
navigation.depth                                // 1
```

---

## Installation

```swift
dependencies: [
    .package(url: "https://github.com/swift-foundations/swift-navigation.git", branch: "main")
]
```

```swift
.target(
    name: "YourTarget",
    dependencies: [
        .product(name: "Navigation", package: "swift-navigation")
    ]
)
```

Requires Swift 6.3.3. Platform minimums: macOS 26, iOS 26, tvOS 26, watchOS 26, visionOS 26. The
only dependency is `swift-navigation-primitives`, which the module re-exports; no Foundation is
imported anywhere.

> **Name collision.** The package name `swift-navigation` collides with an unrelated external
> package of the same name. Manifests spell dependencies by exact canonical URL, so identity stays
> unambiguous inside a dependency closure.

---

## Architecture

One library product over a single source module, re-exporting the L1 vocabulary.

| Product | When to import |
|---------|----------------|
| `Navigation` | Holding navigation state anywhere — a client shell, a server request, a test. |

| Type | Purpose |
|------|---------|
| `Navigation.Tree` | One level: a root destination, a stack above it, and the levels it presents. |
| `Navigation.Presented` | A level shown over another, paired inseparably with the presentation showing it. |
| `Navigation.Destination`, `Navigation.Stack`, `Navigation.Presentation`, `Navigation.Identity` | Re-exported from `swift-navigation-primitives`. |

### What lives elsewhere

**Deep links.** Turning a URL into navigation state, or navigation state back into a URL, belongs
to the consumer that owns both the destination type and its route grammar. Mapping a parsed route
onto a tree shape — which destinations land on a stack, which are presented, in what mode, with
whose dismissal authority — is application policy, and a library function would have to invent
that policy on everyone's behalf. This package makes the seam cheap by keeping its structure
public and its construction total, not by depending on a router.

**Store runtimes.** Navigation state is a value, so it sits inside a feature's state like any
other field and its update function mutates it through the operations here. Neither this package
nor a store runtime needs the other's vocabulary, and neither depends on the other.

---

## Community

<!-- BEGIN: discussion -->
*Discussion thread will be created at first public release.*
<!-- END: discussion -->

## License

Apache 2.0. See [LICENSE](LICENSE.md).
