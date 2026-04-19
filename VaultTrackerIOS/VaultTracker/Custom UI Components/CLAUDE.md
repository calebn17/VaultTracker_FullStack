# Custom UI Components

Reusable SwiftUI primitives shared across features.

> **Component specs and defaults:** [`Documentation/system_design.md`](Documentation/system_design.md)

## Components

### `CustomButton`

```swift
CustomButton(label: "Save", labelColor: .white, backgroundColor: .blue) { action }
```

### `CustomTextField`

```swift
CustomTextField(title: "Asset Name", placeholder: "e.g. Bitcoin", text: $name)
```

## Guidelines

- Keep components stateless — accept bindings for mutable values
- No business logic or API calls here
- Add a `#Preview` block to every new component
