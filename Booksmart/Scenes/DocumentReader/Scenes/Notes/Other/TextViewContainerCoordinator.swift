import Cocoa

/// Delegate classes that are passed into the TextView from NSViewControllerRepresentable (as the coordinator) conform to this protocol.
/// It contains methods for sending information out of the TextView to SwiftUI and the other direction.
/// There are two different implementations, because the TextView in the Notes is a bit different from the TextView in the Flashcards.
protocol TextViewContainerDelegate {
    /// Get the contents that should appear in the text view (from Realm). This is called from within the text view and then it displays the content.
    func loadChapterContents() -> CodedTextViewContents?
    
    /// Save the contents currently in the text view in Realm.
    func saveChapterContents(contents: CodedTextViewContents) -> Bool
    
    /// Go to specific page in the book (called when clicking on page link inside text view)
    func goToPage(_ page: Int)
    
    /// Called from text view when it has successfully set up everything.
    func viewDidAppearWithProperties(height: CGFloat)
}
