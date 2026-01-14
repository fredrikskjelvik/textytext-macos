import Combine
import SwiftUI
import Cocoa
import Factory

/// SwiftUI view containing NSViewControllerRepresentable with the text view inside it.
struct TextViewContainer: NSViewControllerRepresentable {
    func makeNSViewController(context: Context) -> TextViewController {
        let textViewController = TextViewController(coordinator: context.coordinator, textContainerInset: NSSize(width: 60.0, height: 30.0), isEditable: true, isScrollable: true)
        
		return textViewController
	}
    
    /// This runs any time one of the binding variables in this class changes, thereby updating the represented NSView
	func updateNSViewController(_ nsViewController: TextViewController, context: Context) {
        nsViewController.reloadView()
	}
    
    func makeCoordinator() -> NotesTextViewContainerCoordinator {
        return NotesTextViewContainerCoordinator(self)
    }
}

/// The coordinator for TextViewContainer. Sends info between SwiftUI and TextView. Conforms to TextViewContainerDelegate.
class NotesTextViewContainerCoordinator: NSObject, TextViewContainerDelegate {
    @Injected(Container.realm) private var realm
    
    let parent: TextViewContainer
    var state: ContentDB?
    
    init(_ parent: TextViewContainer) {
        self.parent = parent
    }
    
    func loadContents() -> CodedTextViewContents? {
        guard let content = realm.objects(ContentDB.self).first else {
            self.state = ContentDB()
            return self.state?.contents
        }
        
        self.state = content
        return self.state?.contents
    }
    
    func saveContents(contents: CodedTextViewContents) -> Bool {
        if (state == nil) {
            return false
        }
        
        try! realm.write {
            state?.contents = contents
        }
        
        return true
    }
    
    func viewDidAppearWithProperties(height: CGFloat) {
        return
    }
}
