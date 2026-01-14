import Cocoa

fileprivate extension NSMenuItem {
    convenience init(title: String, tag: BlocksInfo.Types) {
        self.init()
        self.title = title
        self.tag = tag.rawValue
    }
}

/// Inline Styling Delegate
/// A set of methods to receive inline styling updates.
protocol InlineStylingDelegate: AnyObject {

    /// Sent when an inline style is toggled.
    /// - Parameter toggleStyle:    The style that was toggled.
    /// - Parameter forCharacters:  The character range to update inline styles for.
    /// - Parameter inBlockRange:   The range of blocks that intersect with the character range.
    func inlineStyling(toggleStyle: StyleBuilder.InlineStyles, forCharacters: NSRange, inBlockRange: Range<Int>)

    /// Sent when a block's type is changed.
    /// - Parameter setBlockType:   The new block type.
    /// - Parameter forBlocks:      The range of blocks that should be changed to the new block type.
    func inlineStyling(setBlockType: BlocksInfo.Types, forBlocks: Range<Int>)
    
    /// Sent when user has selected a range of text with a link, and clicks on "Link" button in the inline styling popup. This opens up another popup
    /// to edit the existing link.
    /// - Parameters:
    ///   - editLinkAt: link range
    ///   - url: url of the link
    func inlineStyling(editLinkAt: NSRange, url: URL?)

    /// Sent when user requests to remove a selected link from the inline styling popup.
    /// - Parameters:
    ///    - removeLinkAt: range of link to remove
    func inlineStyling(removeLinkAt: NSRange)
}

fileprivate enum LinkAction: Int, RawRepresentable {
    case edit
    case remove
    case copy
}

/// View Controller for the inline styling popup view. This is the view that appears (after a short delay) when the user selects some text and shows
/// options to make text bold, italic, etc. and also change the block type.
class InlineStylingPopupController: NSViewController {
    static private let linkArrowImage = NSImage(systemSymbolName: "arrow.up.right", accessibilityDescription: nil)!.tinted(with: NSColor.blue)

    @IBOutlet var blockSelectionPopup: NSPopUpButton!
    @IBOutlet var linkButton: NSButton!
    @IBOutlet weak var pageLinkButton: NSButton!
    
    private var linkButtonMenu: NSMenu?

    weak var delegate: InlineStylingDelegate? = nil

    /// The selected character range. The range to which inline styling changes are applied.
    /// Note: Before a displaying the inline styling popup, set both the selectedRange and the selectedBlockRange properties.
    var selectedRange = NSRange()

    /// The character range's corresponding block range, i.e. the blocks that intersect with the character range.
    /// Note: Before a displaying the inline styling popup, set both the selectedRange and the selectedBlockRange properties.
    var selectedBlockRange: Range<Int> = 0 ..< 0

    /// The text selection's link information, if the selected text indeed is a link.
    var selectedLink: (link: URL, range: NSRange)? = nil
    
    var selectionPageLink: Int? = nil

	@IBAction func onChangeBlockSelection(_ sender: Any) {
        view.window?.performClose(sender)

        if let item = blockSelectionPopup.selectedItem, let type = BlocksInfo.Types(rawValue: item.tag) {
            delegate?.inlineStyling(setBlockType: type, forBlocks: selectedBlockRange)
        }
    }
	
	@IBAction func onClickHighlight(_ sender: Any) {
        delegate?.inlineStyling(toggleStyle: .highlight, forCharacters: selectedRange, inBlockRange: selectedBlockRange)
	}
	
	@IBAction func onClickBold(_ sender: Any) {
        delegate?.inlineStyling(toggleStyle: .bold, forCharacters: selectedRange, inBlockRange: selectedBlockRange)
	}
	
	@IBAction func onClickItalic(_ sender: Any) {
        delegate?.inlineStyling(toggleStyle: .italic, forCharacters: selectedRange, inBlockRange: selectedBlockRange)
	}
	
	@IBAction func onClickUnderline(_ sender: Any) {
        delegate?.inlineStyling(toggleStyle: .underline, forCharacters: selectedRange, inBlockRange: selectedBlockRange)
    }
	
	@IBAction func onClickCode(_ sender: Any) {
        delegate?.inlineStyling(toggleStyle: .code, forCharacters: selectedRange, inBlockRange: selectedBlockRange)
	}

    @IBAction func onClickLink(_ sender: Any?) {
        if selectedLink == nil
        {
            view.window?.performClose(sender)
            delegate?.inlineStyling(editLinkAt: selectedRange, url: nil)
        }
        else
        {
            let menu = linkButtonMenu!
            let event = NSApp.currentEvent!
            NSMenu.popUpContextMenu(menu, with: event, for: linkButton)
        }
    }
    
    @objc private func onLinkAction(_ sender: NSButton) {
        guard let selected = selectedLink,
              let action = LinkAction(rawValue: sender.tag) else {
            NSSound.beep()
            return
        }

        switch action {
        case .copy:
            let linkString = selected.link.absoluteString
            let pasteboard = NSPasteboard.general
            pasteboard.declareTypes([.string, .URL], owner: nil)
            pasteboard.setString(linkString, forType: .string)
            pasteboard.setString(linkString, forType: .URL)

        case .edit:
            delegate?.inlineStyling(editLinkAt: selected.range, url: selected.link)

        case .remove:
            delegate?.inlineStyling(removeLinkAt: selected.range)
            setLinkButton(color: NSColor.labelColor, image: nil, position: .noImage)
            selectedLink = nil
        }
    }

    private func createLinkMenuItem(title: String, image: String, tag: LinkAction) -> NSMenuItem {
        let item = NSMenuItem()
            item.target = self
            item.action = #selector(onLinkAction(_:))
            item.title = title
            item.image = NSImage(systemSymbolName: image, accessibilityDescription: nil)
            item.tag = tag.rawValue
        
        return item
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        initializeBlockSelectionPopup()

        linkButtonMenu = NSMenu(items: [
            createLinkMenuItem(title: "Edit link", image: "link", tag: .edit),
            createLinkMenuItem(title: "Copy link", image: "doc.on.doc", tag: .copy),
            createLinkMenuItem(title: "Remove link", image: "trash", tag: .remove)
        ])
    }

    private func setLinkButton(color: NSColor, image: NSImage?, position: NSControl.ImagePosition) {
        linkButton.image = image
        linkButton.imagePosition = position

        linkButton.attributedTitle = NSAttributedString(string: "Link", attributes: [
            .font : NSFont.systemFont(ofSize: NSFont.systemFontSize),
            .foregroundColor : color,
        ])
    }

	override func viewWillAppear() {
        super.viewWillAppear()

        if selectedLink == nil {
            setLinkButton(color: NSColor.labelColor, image: nil, position: .noImage)
        } else {
            setLinkButton(color: NSColor.blue, image: InlineStylingPopupController.linkArrowImage, position: .imageLeft)
        }
    }
	
	func initializeBlockSelectionPopup() {
        blockSelectionPopup.menu?.items = [
            NSMenuItem(title: "Text",         tag: .text),
            NSMenuItem(title: "Header",       tag: .header1),
            NSMenuItem(title: "Subheader",    tag: .header2),
            NSMenuItem(title: "List",         tag: .list),
            NSMenuItem(title: "Ordered List", tag: .orderedlist),
            NSMenuItem(title: "Code",         tag: .codesnippet)
        ]

		blockSelectionPopup.selectItem(at: 0)
	}
}
