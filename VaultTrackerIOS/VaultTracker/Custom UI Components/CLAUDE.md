# Custom UI Components

Reusable SwiftUI primitives shared across features.

## Components

### `CustomButton`
A styled button with configurable label text, label colour, and background colour. Uses a `RoundedRectangle` with `cornerRadius: 10`.

Usage:
```swift
CustomButton(label: "Save", labelColor: .white, backgroundColor: .blue) {
    // action
}
```

### `CustomTextField`
A labelled text field with a bordered, rounded style. All visual properties have defaults and can be overridden.

| Property | Default |
|----------|---------|
| `cornerRadius` | `8` |
| `borderColor` | `.gray` |
| `borderWidth` | `1` |
| `backgroundColor` | `Color(.systemBackground)` |

Usage:
```swift
CustomTextField(title: "Asset Name", placeholder: "e.g. Bitcoin", text: $name)
```

## Guidelines

- Keep components stateless where possible — accept bindings for mutable values.
- Do not add business logic or API calls here.
- Add a `#Preview` block to every new component.
