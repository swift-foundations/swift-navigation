# ``Navigation``

@Metadata {
    @DisplayName("Navigation")
    @TitleHeading("Swift Foundations")
}

Tree-based navigation state: levels of identified destinations, composed through presentations.

## Overview

A level is a stack — a destination to start from, and whatever has been pushed above it —
together with the levels it presents. A presented level is a level in its own right and presents
in turn, so navigation state nests: it is a tree of levels, not a flat list of screens, which is
what lets a sheet own a stack of its own without the two stacks contaminating each other.

Two invariants shape the model. Presentations belong to the level rather than to any destination
in it, so pushing or popping beneath a sheet does not disturb it — which is what a person sees. A
level presents at most one thing per mode, so a modal and a modeless presentation may stand at
once while a second modal presentation must nest inside the first, which is where it renders
anyway.

The vocabulary the tree is built from — placement, identity, ordering, presentation — belongs to
`swift-navigation`, re-exported here.

## What lives elsewhere

Turning a URL into navigation state, or navigation state back into a URL, belongs to the consumer
that owns both the destination type and its route grammar; the mapping from a route onto a tree
shape is application policy. This package makes that cheap by keeping its structure public and its
construction total, not by depending on a router.

Driving navigation from a store runtime likewise belongs to the consumer. Navigation state is a
value, so it sits inside a feature's state like any other field, and neither package needs the
other's vocabulary.

## Topics

### Navigation state

- ``Navigation/Tree``
- ``Navigation/Presented``
