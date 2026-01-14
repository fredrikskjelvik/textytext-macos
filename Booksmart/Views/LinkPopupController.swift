import Cocoa

public protocol LinkPopupDelegate : AnyObject {
    func linkPopup(createLinkAt: NSRange, withText text: String, linkingTo url: URL)
}

class LinkPopupController: NSViewController {
    public enum SelectedText {
        case none
        case link(String)
        case text(String)
        case both(String, String)

        init(_ text: String) {
            if let linkRegex = try? NSRegularExpression(pattern: "https?:\\/\\/([\\w_-]+(?:(?:\\.[\\w_-]+)+))([\\w.,@?^=%&:\\/~+#-]*[\\w@?^=%&\\/~+#-])") {
                if linkRegex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)) != nil {
                    self = .link(text)
                } else {
                    self = .text(text)
                }
            } else {
                self = .none
            }
        }
    }

    private var selectedRange = NSRange()
    private var selectedText: SelectedText = .none
    public var delegate: LinkPopupDelegate? = nil

    @IBOutlet var doneButton: NSButton!
    @IBOutlet var errorMessageView: NSView!
    @IBOutlet var errorMessageField: NSTextField!
    @IBOutlet var nameField: NSTextField!
    @IBOutlet var linkField: NSTextField!

    public func setSelection(range: NSRange, text: SelectedText) {
        selectedRange = range
        selectedText = text
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        errorMessageView.isHidden = true

        switch selectedText {
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

        if case .link = selectedText {
            nameField.becomeFirstResponder()
        } else {
            linkField.becomeFirstResponder()
        }
    }

    @IBAction func onClickCancel(_ sender: Any?) {
        view.window?.performClose(sender)
    }

    private func displayAlert(message: String, for textField: NSTextField) {
        NSSound.beep()

        errorMessageView.isHidden = false
        errorMessageField.stringValue = message

        textField.becomeFirstResponder()
    }

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
}
