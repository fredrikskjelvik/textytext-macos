//
//  BlockHoverViewController.swift
//  LimitlessUI
//

import Cocoa

/// BlockHoverView delegate that handles events. Delegate is TextView.
protocol BlockHoverViewDelegate: NSDraggingSource {
    /// When you click the :: symbol in the BlockHoverView, create an NSMenu with options like "Duplicate", "Delete", etc.
    /// - Returns: NSMenu
    func blockHoverViewContextMenu() -> NSMenu?

    /// When you drag a block via the "Block Hover View" (the plus and drag symbol on the left)
    /// - Parameter event: NSEvent
    func blockHoverViewDidStartDragging(with event: NSEvent)

    /// Handle "Insert" option in BlockHoverView NSMenu. I.e. add a text block directly underneath.
    func blockHoverViewInsert()
}

/// The + symbol in BlockHoverView, i.e. for adding a block directly underneath.
class BlockHoverViewAddButton : NSButton {
    public unowned var delegate: BlockHoverViewDelegate? = nil

    override init(frame: NSRect) {
        super.init(frame: frame)
        self.setButtonType(.pushOnPushOff)
        self.action = #selector(insertBlock(_:))
        self.target = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: NSCursor.arrow)
    }

    @objc func insertBlock(_ sender: Any?) {
        delegate?.blockHoverViewInsert()
    }
}

/// The [] symbol in BlockHoverView, i.e. for dragging a block or getting a menu with options like duplicate and change block type.
class BlockHoverViewMenuButton : NSButton {
    private var mouseDownPoint = NSPoint()
    private var isDragging = false

    public unowned var delegate: BlockHoverViewDelegate? = nil

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: NSCursor.openHand)
    }

    override func mouseDragged(with event: NSEvent) {
        if isDragging == false, event.locationInWindow.distance(from: mouseDownPoint) > 2 {
            delegate?.blockHoverViewDidStartDragging(with: event)
            isDragging = true
        }
    }

    override func mouseDown(with event: NSEvent) {
        mouseDownPoint = event.locationInWindow
        isDragging = false
    }

    override func mouseUp(with event: NSEvent) {
        if isDragging {
            isDragging = false
        } else if let menu = delegate?.blockHoverViewContextMenu() {
            NSMenu.popUpContextMenu(menu, with: event, for: superview ?? self)
        }
    }
}

/// NSView for the view containing the + and [] icon for dragging a block.
/// This view appears when you hover over a block with the cursor.
class BlockHoverView: NSView {
    public var addButton: BlockHoverViewAddButton
    public var menuButton: BlockHoverViewMenuButton

    public override var isFlipped: Bool {
        return true
    }
    
    public init(inset: NSSize = NSSize(width: 60, height: 60)) {
        let buttonSize = inset.width / 2.5
        
        // Set buttons
        let titleAttrs: [NSAttributedString.Key : Any] = [
            .foregroundColor : NSColor.lightGray,
            .font : NSFont.monospacedSystemFont(ofSize: buttonSize, weight: .regular)
        ]
        
        addButton = BlockHoverViewAddButton(frame: NSRect(x: 0, y: 0, width: buttonSize, height: buttonSize))
        addButton.attributedTitle = NSAttributedString(string: "＋", attributes: titleAttrs)
        addButton.isBordered = false

        menuButton = BlockHoverViewMenuButton(frame: NSRect(x: buttonSize, y: 0, width: buttonSize, height: buttonSize))
        menuButton.attributedTitle = NSAttributedString(string: "⠿", attributes: titleAttrs)
        menuButton.isBordered = false
        
        // Set frame
        let frameSize = NSSize(width: buttonSize * 2, height: buttonSize)
        let frameOrigin = NSPoint(x: inset.width - frameSize.width, y: inset.height)
        let frame = NSRect(origin: frameOrigin, size: frameSize)
        
        super.init(frame: frame)
        
        subviews = [addButton, menuButton]
    }
    
    required init?(coder: NSCoder) {
        return nil
    }
}

/// NSViewController for the view containing the + and [] icon for dragging a block (i.e. BlockHoverView)
class BlockHoverViewController: NSViewController {
    public unowned var delegate: BlockHoverViewDelegate? = nil {
        didSet {
            if let view = self.view as? BlockHoverView {
                view.menuButton.delegate = delegate
                view.addButton.delegate = delegate
            }
        }
    }
    
    init(inset: NSSize) {
        super.init(nibName: nil, bundle: nil)
        self.view = BlockHoverView(inset: inset)
        self.view.isHidden = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func setHidden(_ hidden: Bool, animate: Bool = true) {
        if view.isHidden == hidden {
            return
        }

        if animate == false {
            view.isHidden = hidden
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.4
            self.view.animator().alphaValue = hidden ? 0 : 1
        } completionHandler: {
            self.view.isHidden = hidden
            self.view.alphaValue = 1
        }
    }
}
