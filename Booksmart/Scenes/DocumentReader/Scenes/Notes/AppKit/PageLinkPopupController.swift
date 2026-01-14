import Cocoa

/// Delegate responsible for making changes to the text view based on user input which is handled in LinkPopupController
public protocol PageLinkPopupDelegate : AnyObject {
    func pageLinkPopup(createLinkAt: NSRange, setPage page: Int)
    func pageLinkPopup(deleteLinkAt range: NSRange)
}

class PageLinkPopupController: NSViewController {
    /// The selected range in the textview that prompted this popup to open
    private var selectedRange = NSRange()
    /// See protocol
    public var delegate: PageLinkPopupDelegate? = nil

    @IBOutlet weak var pageField: NSTextField!
    
    var page: Int = 0
    
    func setSelection(range: NSRange, page: Int?) {
        self.selectedRange = range
        self.page = page ?? 0
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        pageField.stringValue = String(page)
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        
        pageField.becomeFirstResponder()
    }

    @IBAction func onClickDelete(_ sender: Any) {
        delegate?.pageLinkPopup(deleteLinkAt: selectedRange)
    }
    
    @IBAction func onClickSubmit(_ sender: Any) {
        let pageString = pageField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let page = Int(pageString) else {
            return
        }
        
        delegate?.pageLinkPopup(createLinkAt: selectedRange, setPage: page)
    }
}
