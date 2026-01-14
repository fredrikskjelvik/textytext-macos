import Combine
import SwiftUI
import Cocoa

/// SwiftUI view containing NSViewRepresentable with the text view
struct FlashcardsTextViewContainer: NSViewControllerRepresentable {
    @Binding var content: CodedTextViewContents?
    var isEditable: Bool
    var isScrollable: Bool
    @Binding var idealHeight: Double?
    
    func makeNSViewController(context: Context) -> TextViewController {
        let size: NSSize
        if isEditable
        {
            size = NSSize(width: 50.0, height: 10.0)
        }
        else
        {
            size = NSSize(width: 20.0, height: 20.0)
        }
        
        let textViewController = TextViewController(coordinator: context.coordinator, textContainerInset: size, isEditable: isEditable, isScrollable: isScrollable)
        
        return textViewController
    }
    
    func updateNSViewController(_ nsViewController: TextViewController, context: Context) {}
    
    func makeCoordinator() -> FlashcardsTextViewContainerCoordinator {
        return FlashcardsTextViewContainerCoordinator(self)
    }
}

/// The coordinator for FlashcardsTextViewContainer. Sends info between SwiftUI and TextView. Conforms to TextViewContainerDelegate.
class FlashcardsTextViewContainerCoordinator: NSObject, TextViewContainerDelegate {
    let parent: FlashcardsTextViewContainer
    
    init(_ parent: FlashcardsTextViewContainer) {
        self.parent = parent
    }
    
    func loadChapterContents() -> CodedTextViewContents? {
        return parent.content
    }
    
    func saveChapterContents(contents: CodedTextViewContents) -> Bool {
        parent.content = contents
        
        return true
    }
    
    func goToPage(_ page: Int) {
        fatalError("Not implemented, should prevent this feature in UI.")
    }
    
    func viewDidAppearWithProperties(height: CGFloat) {
        parent.idealHeight = height
    }
}
