# textytext

Textytext is a native MacOS rich text editor with UX similar to Notion. I.e. a block-based text editor which supports several block types, including text, header, image, code snippet, bullet list, and numbered list.

The text editor is written entirely in Swift with AppKit, and then wrapped in a NSViewControllerRepresentable so you can deploy the text editor as a SwiftUI component just like this:

```swift
import SwiftUI

struct EditorContainer: View {
    var body: some View {
        TextViewContainer()
    }
}
```

# Functionality

### Basic text editing
video 1
![Feature demo - basic text editing](./readme-assets/feature-1.gif)

### Lists (bullet & numbered)
![Feature demo - lists, bullet & numbered list](./readme-assets/feature-2.gif)

### Images
![Feature demo - images](./readme-assets/feature-3.gif)

### Code snippets
![Feature demo - code snippets](./readme-assets/feature-4.gif)

### Links
![Feature demo - Links](./readme-assets/feature-5.gif)
