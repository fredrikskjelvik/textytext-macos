import Foundation

protocol TextViewCommand {
    func shouldExecute() -> Bool
    func execute(textView: TextView)
}

extension TextViewCommand {
    func shouldExecute() -> Bool {
        return true
    }
}

/// Set deferred selection to some range, then programatically make some edit (add some text, add a block), and after that edit, set the selection to deferredSelection.
/// Example use case: When creating a code block you automatically create an empty text block below, but after that you set the selection to within the codeblock itself,
/// not the newly created empty text block.
struct DeferredSelectionCommand: TextViewCommand {
    let selection: NSRange
    
    func execute(textView: TextView) {
        textView.setSelectedRange(selection)
    }
}

struct DisplayPageLinkPopup: TextViewCommand {
    let selection: NSRange
    
    func execute(textView: TextView) {
        textView.displayPageLinkPopup(for: selection)
    }
}
