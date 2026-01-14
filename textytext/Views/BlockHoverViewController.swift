//
//  BlockHoverViewController.swift
//  LimitlessUI
//

import Cocoa

protocol BlockHoverViewDelegate : NSDraggingSource {
    func blockHoverViewContextMenu() -> NSMenu?

    func blockHoverViewDidStartDragging(with event: NSEvent)

    func blockHoverViewInsert()
}

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

class BlockHoverView: NSView {
    public var addButton: BlockHoverViewAddButton
    public var menuButton: BlockHoverViewMenuButton

    public override var isFlipped: Bool {
        return true
    }

    public init() {
        let buttonWidth = 22
        let buttonHeight = 22

        let titleAttrs: [NSAttributedString.Key : Any] = [
            .foregroundColor : NSColor.lightGray,
            .font : NSFont.monospacedSystemFont(ofSize: 22, weight: .regular)
        ]

        addButton = BlockHoverViewAddButton(frame: NSRect(x: 0, y: 0, width: buttonWidth, height: buttonHeight))
        addButton.attributedTitle = NSAttributedString(string: "＋", attributes: titleAttrs)
        addButton.isBordered = false

        menuButton = BlockHoverViewMenuButton(frame: NSRect(x: buttonWidth, y: 0, width: buttonWidth, height: buttonHeight))
        menuButton.attributedTitle = NSAttributedString(string: "⠿", attributes: titleAttrs)
        menuButton.isBordered = false

        super.init(frame: NSRect(x: 0, y: 0, width: buttonWidth * 2, height: buttonHeight))
        subviews = [addButton, menuButton]
    }

    required init?(coder: NSCoder) {
        return nil
    }
}

class BlockHoverViewController: NSViewController {
    public unowned var delegate: BlockHoverViewDelegate? = nil {
        didSet {
            if let view = self.view as? BlockHoverView {
                view.menuButton.delegate = delegate
                view.addButton.delegate = delegate
            }
        }
    }

    init() {
        super.init(nibName: nil, bundle: nil)
        view = BlockHoverView()
        view.isHidden = true
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
