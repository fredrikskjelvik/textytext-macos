import Cocoa

/// Delegate responsible for making changes to the text view based on user input which is handled in LinkPopupController
public protocol LinkPopupDelegate: AnyObject {
    /// Runs when user has submitted link creation form inside the popup (i.e. link title and url). Actually creates the link in the
    /// text view.
    /// - Parameters:
    ///   - createLinkAt: range of text to turn into link
    ///   - text: what the link text should be (either the url itself if no link title was provided, otherwise link title)
    ///   - url: url to go to
    func linkPopup(createLinkAt: NSRange, withText text: String, linkingTo url: URL)
}

class LinkPopupController: NSViewController {
    /// Encapsulates the information available about the selected text. Whether it already has an associated link and/or title, or "none" (not a link, i.e. creating from scratch)
    public enum SelectedText {
        case none
        case link(String)
        case text(String)
        case both(String, String)

        init(_ text: String) {
            if let linkRegex = try? NSRegularExpression(pattern: "https?:\\/\\/([\\w_-]+(?:(?:\\.[\\w_-]+)+))([\\w.,@?^=%&:\\/~+#-]*[\\w@?^=%&\\/~+#-])")
            {
                if linkRegex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)) != nil
                {
                    self = .link(text)
                }
                else
                {
                    self = .text(text)
                }
            }
            else
            {
                self = .none
            }
        }
    }

    /// The selected range in the textview that prompted this popup to open
    private var selectedRange = NSRange()
    /// See enum
    private var selectedText: SelectedText = .none
    /// See protocol
    public var delegate: LinkPopupDelegate? = nil

    @IBOutlet var doneButton: NSButton!
    @IBOutlet var errorMessageView: NSView!
    @IBOutlet var errorMessageField: NSTextField!
    @IBOutlet var nameField: NSTextField!
    @IBOutlet var linkField: NSTextField!
    
    /// Pass the required info (range, text, and url) from a selection. This is always done before displaying the popup.
    /// - Parameters:
    ///   - range: current range
    ///   - text: the title and/or URL of the current selection
    public func setSelection(range: NSRange, text: SelectedText) {
        selectedRange = range
        selectedText = text
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        
        initializeView()
    }
    
    /// Set the name and link fields based on what information is available, hide the error message view initially, set
    /// the submit button based on whether in edit or create mode.
    private func initializeView() {
        errorMessageView.isHidden = true

        switch selectedText
        {
        case .none:
            nameField.stringValue = ""
            linkField.stringValue = ""

        case .link(let string):
            nameField.stringValue = ""
            linkField.stringValue = string

        case .text(let string):
            nameField.stringValue = string
            linkField.stringValue = ""

        case .both(let name, let link):
            nameField.stringValue = name
            linkField.stringValue = link
            doneButton.title = "Edit link"
            return
        }

        doneButton.title = "Create link"
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        
        setFocusOnRelevantField()
    }
    
    /// Set focus depending on what field is already set
    private func setFocusOnRelevantField() {
        if case .link = selectedText {
            nameField.becomeFirstResponder()
        } else {
            linkField.becomeFirstResponder()
        }
    }

    /// On click cancel button. Close popup.
    @IBAction func onClickCancel(_ sender: Any?) {
        view.window?.performClose(sender)
    }
    
    /// On click create link event. Trim fields, check if fields are non-empty, and check if url is valid. Then send to delegate to actually
    /// update the text view.
    /// - Parameter sender: any sender
    @IBAction func onClickCreateLink(_ sender: Any?) {
        let name = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let link = linkField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)

        if link.isEmpty {
            return displayAlert(message: "Link required", for: linkField)
        }

        guard let url = URL(string: link) else {
            return displayAlert(message: "Invalid URL", for: linkField)
        }

        if name.isEmpty {
            delegate?.linkPopup(createLinkAt: selectedRange, withText: link, linkingTo: url)
        } else {
            delegate?.linkPopup(createLinkAt: selectedRange, withText: name, linkingTo: url)
        }
    }
    
    /// Display an error message within the link popup controller. Set focus to the field containing the error.
    /// - Parameters:
    ///   - message: The message to show
    ///   - textField: The text field containing the error.
    private func displayAlert(message: String, for textField: NSTextField) {
        NSSound.beep()

        errorMessageView.isHidden = false
        errorMessageField.stringValue = message

        textField.becomeFirstResponder()
    }
}
