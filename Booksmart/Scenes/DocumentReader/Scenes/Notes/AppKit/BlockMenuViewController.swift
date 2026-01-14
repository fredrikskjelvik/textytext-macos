//
//  BlockTypeViewController.swift
//  LimitlessUI
//

import Cocoa

protocol BlockMenuDelegate: AnyObject {
    /// Delegate method for handling when a block type is selected via the block menu. Create the block of the selected type
    /// and place it correctly in the text view
    /// - Parameters:
    ///   - commandRange: the text range of the "/" that was written to open the menu. this slash is removed.
    ///   - in: the current block
    ///   - createBlockOfType: the block type to convert current block into
    func blockMenu(commandRange: NSRange, in: Block, createBlockOfType: BlocksInfo.Types)
}

/// A single cell inside BlockMenuViewController showing the name of a block, its description, and an icon
class BlockMenuCellView : NSTableCellView {
    var blockType: BlocksInfo.Types = .text
    
    @IBOutlet var blockIcon: NSImageView!
    @IBOutlet var blockName: NSTextField!
    @IBOutlet var blockDescription: NSTextField!

    /// Populate the block menu cell view with information about a particular block type retrieved from the BlocksInfo struct
    func setBlockType(_ type: BlocksInfo.Types) {
        guard let info = BlocksInfo.get(type) else {
            return
        }

        blockType = type
        blockIcon.image = info.icon
        blockName.stringValue = info.name
        blockDescription.stringValue = info.description
    }
}

class BlockMenuRowView: NSTableRowView {
    static let selectionColor = NSColor(srgbRed: 0.95, green: 0.95, blue: 0.95, alpha: 1)

    override func drawSelection(in dirtyRect: NSRect) {
        BlockMenuRowView.selectionColor.setFill()
        dirtyRect.fill()
    }
}

class BlockMenuView : NSView {
    required init?(coder: NSCoder) {
        super.init(coder: coder)

        let shadow = NSShadow()
        shadow.shadowColor = NSColor.lightGray
        shadow.shadowBlurRadius = 6
        shadow.shadowOffset = NSSize(width: 0, height: -4)

        self.wantsLayer = true
        self.shadow = shadow
    }
}

/// Filter the list of supported block types by the provided text (startsWith)
fileprivate func filter(types: [BlocksInfo.Types], by text: String) -> [BlocksInfo.Types] {
    // TODO: Give block types additional alias names so they are more easily searchable without knowing the exact name
    
    if text.isEmpty {
        return types
    }

    var filtered: [(type: BlocksInfo.Types, location: String.Index)] = []

    for type in types
    {
        if let info = BlocksInfo.get(type),
           let location = info.name.range(of: text, options: [.caseInsensitive], range: nil, locale: nil)
        {
            filtered.append((type, location.lowerBound))
        }
    }

    filtered.sort(by: {$0.location < $1.location})
    return filtered.map({$0.type})
}

/// Controller for the view that appears when you type "/" and select a block type to create
final class BlockMenuViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    /// Block types that should be shown in this menu
    static private let supportedTypes: [BlocksInfo.Types] = [
        .text,
        .header1,
        .header2,
        .list,
        .orderedlist,
        .codesnippet,
        .image
    ]

    private enum ViewPosition {
        case below
        case above
    }

    @IBOutlet private var tableView: NSTableView!
    @IBOutlet private var noResultsLabel: NSTextField!

    private var block: Block?
    private var initialBlockLength = 0
    private var noResultsCount = 0

    private var types: [BlocksInfo.Types] = []
    private var textRange = NSRange()
    private var slashPosition = NSRect()
    private var viewPosition: ViewPosition? = nil

    private(set) public var isOpen = false
    private unowned var textView: TextView?
    public unowned var delegate: BlockMenuDelegate?

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        return BlockMenuRowView()
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = NSUserInterfaceItemIdentifier(rawValue: "BlockTypeCellView")

        guard let view = tableView.makeView(withIdentifier: identifier, owner: self) as? BlockMenuCellView else {
            return nil
        }

        view.setBlockType(types[row])
        return view
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        return types.count
    }

    func didDisplayMenu(for block: Block) {
        tableView.selectRowIndexes([0], byExtendingSelection: false)
        self.block = block
    }

    /// Move the selected row up or down by the given delta (usually -1 or 1 obviously) (e.g. when user presses up or down arrow)
    private func moveSelection(by delta: Int) {
        let oldSelection = tableView.selectedRow
        let newSelection: Int

        if oldSelection == -1
        {
            newSelection = 0
        }
        else
        {
            newSelection = oldSelection + delta
        }

        if newSelection >= 0 && newSelection < tableView.numberOfRows
        {
            tableView.selectRowIndexes([newSelection], byExtendingSelection: false)
            tableView.scrollRowToVisible(newSelection)
        }
    }

    private func notifyDelegate() {
        let selection = tableView.selectedRow
        let selectionWithinValidRange = selection >= 0 && selection < types.count

        if selectionWithinValidRange, let block = self.block
        {
            var commandRange = textRange
            commandRange.location -= 1
            commandRange.length += 1

            delegate?.blockMenu(commandRange: commandRange, in: block, createBlockOfType: types[selection])
        }
        else
        {
            NSSound.beep()
        }

        dismiss()
    }

    @IBAction func clickedRow(_ sender: Any?) {
        notifyDelegate()
        dismiss()
    }

    private func setViewFrame(withPosition position: ViewPosition?) {
        guard let textView = self.textView else {
            return
        }

        let frame = textView.frame
        let inset = textView.textContainerOrigin
        let visible = textView.visibleRect

        let slashRect = slashPosition
        let rectMaxY = slashRect.maxY
        let spaceAbove = slashRect.origin.y - visible.origin.y - 20
        let spaceBelow = visible.maxY - rectMaxY - 20

        let width = min(260, max(frame.size.width - inset.x - 8, 8))
        let viewPosition: ViewPosition

        if let pos = position
        {
            viewPosition = pos
        }
        else
        {
            if spaceAbove > spaceBelow
            {
                viewPosition = .above
            }
            else
            {
                viewPosition = .below
            }

            self.viewPosition = viewPosition
        }

        if types.isEmpty
        {
            noResultsLabel.isHidden = false
            noResultsCount += 1

            if viewPosition == .above
            {
                let height = min(spaceAbove, 30)
                view.frame = NSRect(x: inset.x, y: slashRect.origin.y - height - 4, width: width, height: height)
            }
            else
            {
                let height = min(spaceBelow, 30)
                view.frame = NSRect(x: inset.x, y: rectMaxY + 4, width: width, height: height)
            }
        }
        else
        {
            noResultsLabel.isHidden = true
            noResultsCount = 0

            let maxHeight = min(300, tableView.rowHeight * CGFloat(types.count))

            if viewPosition == .above
            {
                let height = max(min(maxHeight, spaceAbove), 8)
                view.frame = NSRect(x: inset.x, y: slashRect.origin.y - height - 4, width: width, height: height)
            }
            else
            {
                let height = max(min(maxHeight, spaceBelow), 8)
                view.frame = NSRect(x: inset.x, y: rectMaxY + 4, width: width, height: height)
            }

            tableView.selectRowIndexes([0], byExtendingSelection: false)
        }
    }

    public func display(in textView: TextView, atCharacter characterIndex: Int, inBlock block: Block) {
        guard let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else {
            return
        }

        let inset = textView.textContainerOrigin

        let characterRange = NSRange(location: characterIndex, length: 1)
        let glyphRange = layoutManager.glyphRange(forCharacterRange: characterRange, actualCharacterRange: nil)
        var rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        rect.origin.y += inset.y

        self.block = block
        self.isOpen = true
        self.textView = textView
        self.initialBlockLength = block.length
        self.textRange = NSRange(location: characterIndex + 1, length: 0)
        self.slashPosition = rect

        textView.addSubview(view)
    }

    override func viewWillAppear() {
        types = BlockMenuViewController.supportedTypes
        tableView.reloadData()
        setViewFrame(withPosition: nil)
    }

    public func dismiss() {
        if isOpen {
            view.removeFromSuperview()
            isOpen = false
        }

        block = nil
    }
    
    /// This method is called when a text edit has been made (didChangeText()) while the block menu view is open.
    /// It filters what is shown in the menu as the user types, and dismisses the menu if:
    /// the text change is not a pure insertion and/or what the user has typed so far does not match the name of a block
    /// - Parameters:
    ///   - block: the block where the edit took place
    ///   - edit: the type of edit that took place
    public func didEdit(block: Block, edit: BlockEdit) {
        switch edit
        {
            case .multiBlockEdit,
                 .replaceWithLines:
                return dismiss()

            case  .replace(let range, _),
                  .insert(let range, _),
                  .deleteLastCharacter(let range):
                if textRange.contains(range: range) == false {
                    return dismiss()
                }
        }

        let newBlockLength = block.length

        if newBlockLength < initialBlockLength {
            return dismiss()
        }

        textRange.length = block.length - initialBlockLength
        let text = block.blockStorage.mutableString.substring(with: textRange)

        types = filter(types: BlockMenuViewController.supportedTypes, by: text)
        tableView.reloadData()
        setViewFrame(withPosition: viewPosition)

        if noResultsCount > 2 {
            dismiss()
        }
    }

    
    // If the block menu is open, send the command to it to handle it, and it will return true if
    // it handled it and therefore TextView should not handle it
    
    /// Handle a NSStandardKeyBindingResponding event sent from TextView
    /// - Parameter command: an NSStandardKeyBindingResponding such as e.g. insertedTab or moveUp
    /// - Returns: true if the block menu handled this NSStandardKeyBindingResponding, and therefore the textview that sent the event should not handle the event within its own view. false otherwise.
    public func handle(command: Selector) -> Bool {
        switch command {
            case #selector(moveUp(_:)):
                moveSelection(by: -1)

            case #selector(moveDown(_:)):
                moveSelection(by: 1)

            case #selector(insertNewline(_:)):
                notifyDelegate()

            case #selector(cancelOperation(_:)):
                dismiss()

            default:
                return false
        }

        return true
    }

    public func didCommand(by selector: Selector) {
        guard let textView = self.textView else {
            return dismiss()
        }

        switch textView.selection {
        case .multiBlock:
            return dismiss()

        case .singleBlock(_, let range):
            if textRange.contains(range: range) == false {
                return dismiss()
            }

        case .none:
            if textRange.contains(range: textView.selectedRange()) == false {
                return dismiss()
            }
        }
    }
}
