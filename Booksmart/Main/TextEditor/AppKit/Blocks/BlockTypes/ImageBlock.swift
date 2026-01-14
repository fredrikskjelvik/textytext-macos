import Cocoa
import UniformTypeIdentifiers

class ImageBlock: Block {
    public let attachment: NSTextAttachment
    private let attachmentCell: ImageBlockTextAttachmentCell
    public var fileName: String? = nil

    public init(owner: TextBlockStorage, range: NSRange, index: Int = 0, image: NSImage? = nil) {
        attachmentCell = ImageBlockTextAttachmentCell()
        attachmentCell.image = image
        
        if image != nil {
            self.fileName = randomAlphaNumericString(length: 35)
        }

        attachment = NSTextAttachment()
        attachment.attachmentCell = attachmentCell

        let adjustedRange = insertAttachment(at: range, in: owner)
        super.init(owner: owner, type: .image, style: blockStyle(), range: adjustedRange, index: index)

        attachmentCell.block = self

        if index == owner.blocks.count {
            owner.appendBlock(TextBlock(owner: owner, range: NSRange()))
        }

        applyStyles()
    }

    public init(from coded: Coded, owner: TextBlockStorage, offset: Int, index: Int) throws {
        attachmentCell = ImageBlockTextAttachmentCell()
        fileName = coded.fileName
        
        if let data = coded.getImageFromLocal()
        {
            attachmentCell.image = NSImage(data: data)
            attachmentCell.imageSize = coded.size
            attachmentCell.position = coded.position
        }

        attachment = NSTextAttachment()
        attachment.attachmentCell = attachmentCell

        let adjustedRange = insertAttachment(at: NSRange(location: offset, length: 0), in: owner)
        super.init(owner: owner, type: .image, style: blockStyle(), range: adjustedRange, index: index)

        attachmentCell.block = self
        applyStyles()
    }

    required init(copy block: Block) {
        let imageBlock = block as! ImageBlock

        attachmentCell = ImageBlockTextAttachmentCell()
        attachmentCell.image = imageBlock.attachmentCell.image
        attachmentCell.position = imageBlock.attachmentCell.position
        attachmentCell.imageSize = imageBlock.attachmentCell.imageSize

        attachment = NSTextAttachment()
        attachment.attachmentCell = attachmentCell
        
        fileName = imageBlock.fileName

        super.init(owner: block.blockStorage, type: .image, style: block.style, range: block.range, index: block.index)
        attachmentCell.block = self
    }

    public var image: NSImage? {
        return attachmentCell.image
    }

    struct Coded: Codable {
        let fileName: String?
        let size: NSSize
        let position: ImagePosition
        
        init(_ block: Block) throws {
            guard let imageBlock = block as? ImageBlock else {
                throw BlockCodingError.invalidType
            }
            
            let attachmentCell = imageBlock.attachmentCell
            
            if let fileName = imageBlock.fileName,
               let image = attachmentCell.image
            {
                self.size = attachmentCell.imageSize
                self.position = attachmentCell.position
                self.fileName = fileName
                
                let storage = try LocalStorageHandler()
                try storage.setImage(image: image, withName: fileName)
            }
            else
            {
                self.size = NSSize()
                self.position = .center
                self.fileName = nil
            }
        }
        
        func getImageFromLocal() -> Data? {
            guard let storage = try? LocalStorageHandler() else {
                return nil
            }
            
            guard let fileName = fileName else {
                return nil
            }

            return try? storage.getImage(withFileName: fileName)
        }
    }

    override func didRemove() {
        attachmentCell.removeSubviews()
    }

    override var isTextSelectable: Bool {
        return false
    }

    override var isConvertable: Bool {
        return false
    }

    override func copy() -> (block: Block, content: NSAttributedString) {
        let copy = ImageBlock(copy: self)

        let baseString = String(UnicodeScalar(NSTextAttachment.character)!)
        let content = NSMutableAttributedString(string: baseString + "\n", attributes: copy.style.attributes)
        content.addAttribute(.attachment, value: copy.attachment, range: NSRange(location: 0, length: baseString.utf16.count))

        return (copy, content)
    }

    override func applyStyles(withUndo: Bool = false) {
        guard length != 0, let textView = blockStorage.textView else {
            return
        }

        if withUndo == false || textView.shouldChangeText(in: range, replacementString: nil) {
            let attachmentRange = NSRange(location: offset, length: 1)

            textStorage.setAttributes(style.attributes, range: range)
            textStorage.addAttribute(.attachment, value: attachment, range: attachmentRange)
            blockStorage.edited([.editedAttributes], range: range, changeInLength: 0)

            if withUndo {
                textView.didChangeText()
            }
        }
    }

    override func adjustSelection(_ selection: NSRange, inDirection: NSSelectionAffinity) -> NSRange? {
        return nil
    }

    override func willConvert() -> NSRange {
        fatalError("Block not convertible")
    }

    override func willMerge(didDeleteCharacters deletedCount: Int = 0) -> Int {
        let newLength = length - deletedCount

        if newLength > 1, let textView = blockStorage.textView {
            let range = NSRange(location: offset, length: newLength - 1)

            if textView.shouldChangeText(in: range, replacementString: "") {
                textStorage.replaceCharacters(in: range, with: "")
                blockStorage.edited([.editedCharacters], range: range, changeInLength: -range.length)
                textView.didChangeText()

                return range.length
            }
        }

        return newLength
    }

    override func didDeleteLastCharacter() {
        let blockIndex = index
        let range = NSRange(location: offset, length: length - 1)

        blockStorage.deleteBlocks(inRange: blockIndex ..< blockIndex + 1, withCharacterRange: range)
    }

    fileprivate func registerUndoResizeImage(from oldSize: NSSize, to newSize: NSSize) {
        guard let undoManager = blockStorage.textView?.undoManager else {
            return
        }

        undoManager.beginUndoGrouping()

        undoManager.registerUndo(withTarget: self, handler: {block in
            block.attachmentCell.imageSize = oldSize
            block.invalidateLayout()
            block.blockStorage.textView.needsDisplay = true
            block.registerUndoResizeImage(from: newSize, to: oldSize)
        })

        undoManager.endUndoGrouping()
    }

    fileprivate func invalidateLayout() {
        blockStorage.updateBlock(self)
        let range = NSRange(location: offset, length: length)

        for manager in blockStorage.layoutManagers {
            manager.invalidateLayout(forCharacterRange: range, actualCharacterRange: nil)
        }
    }
    
    /// Not in use currently, might be used later
    public func unsetImage() {
        self.fileName = nil
        attachmentCell.image = nil
    }

    public func setImage(image: NSImage?) {
        let oldImage = attachmentCell.image
        attachmentCell.image = image
        invalidateLayout()
        
        let oldFilename = fileName
        self.fileName = image != nil ? randomAlphaNumericString(length: 35) : nil

        let textView = blockStorage.textView!
        textView.window?.invalidateCursorRects(for: textView)

        if let undoManager = textView.undoManager {
            undoManager.beginUndoGrouping()

            undoManager.registerUndo(withTarget: self, handler: {block in
                block.setImage(image: oldImage)
                block.fileName = oldFilename
            })

            undoManager.endUndoGrouping()
        }

        textView.needsDisplay = true
    }

    private func setImage(url: URL, window: NSWindow) {
        guard let image = NSImage(contentsOf: url) else {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "Failed to load image."
            alert.beginSheetModal(for: window, completionHandler: nil)
            return
        }

        blockStorage.textView.breakUndoCoalescing()
        
        setImage(image: image)
    }

    fileprivate func selectImage(in window: NSWindow) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image]

        panel.beginSheetModal(for: window, completionHandler: {response in
            if response == .OK, let url = panel.url {
                self.setImage(url: url, window: window)
            }
        })
    }

    @objc private func performContextMenuAction(_ sender: NSMenuItem) {
        guard let action = ImageBlockMenuAction(rawValue: sender.tag) else {
            return
        }

        switch action {
        case .delete:
            deleteBlock()

        case .duplicate:
            duplicateBlock()

        case .replace:
            replaceImage()

        case .download:
            downloadImage()

        case .alignLeft:
            setImagePosition(.left)

        case .alignCenter:
            setImagePosition(.center)

        case .alignRight:
            setImagePosition(.right)
        }
    }

    private func makeMenuItem(withTitle title: String, image: String, action: ImageBlockMenuAction? = nil, submenu: NSMenu? = nil) -> NSMenuItem {
        let item = NSMenuItem()
        item.action = #selector(performContextMenuAction(_:))
        item.target = self
        item.title = title
        item.tag = action?.rawValue ?? -1
        item.submenu = submenu
        item.image = NSImage(systemSymbolName: image, accessibilityDescription: nil)
        return item
    }

    override func contextMenuItems() -> [NSMenuItem] {
        var items = [makeMenuItem(withTitle: "Replace", image: "photo.on.rectangle", action: .replace)]

        if attachmentCell.image != nil {
            items.append(contentsOf: [
                makeMenuItem(withTitle: "Download", image: "square.and.arrow.down", action: .download),
                makeMenuItem(withTitle: "Position", image: "rectangle.split.3x1.fill", submenu: NSMenu(items: [
                    makeMenuItem(withTitle: "Left",   image: "rectangle.lefthalf.inset.fill",  action: .alignLeft),
                    makeMenuItem(withTitle: "Center", image: "rectangle.center.inset.fill",    action: .alignCenter),
                    makeMenuItem(withTitle: "Right",  image: "rectangle.righthalf.inset.fill", action: .alignRight)
                ]))
            ])
        }

        return items
    }

    fileprivate func contextMenu() -> NSMenu {
        var items = [
            makeMenuItem(withTitle: "Delete", image: "trash", action: .delete),
            makeMenuItem(withTitle: "Duplicate", image: "doc.on.doc", action: .duplicate),
        ]

        items.append(contentsOf: contextMenuItems())
        return NSMenu(items: items)
    }

    private func deleteBlock() {
        blockStorage.updateBlock(self)

        let textView = blockStorage.textView!
        textView.beginEditing()
        blockStorage.deleteBlocks(inRange: index ..< index + 1, withCharacterRange: range)
        textView.endEditing()
    }

    private func duplicateBlock() {
        blockStorage.updateBlock(self)

        let insertLocation = index + 1
        let (copy, content) = copy()
        let textView = blockStorage.textView!

        textView.beginEditing()
        blockStorage.insertBlocks([copy], at: insertLocation, contents: content)
        textView.endEditing()
        textView.setSelectedBlocks(insertLocation ..< insertLocation + 1)
    }

    private func downloadImage() {
        guard let image = attachmentCell.image,
              let window = blockStorage.textView?.window else {
            NSSound.beep()
            return
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png, .jpeg]
        panel.allowsOtherFileTypes = false

        panel.beginSheetModal(for: window, completionHandler: {response in
            guard response == .OK, let url = panel.url else {
                return
            }

            struct ImageWriteError: LocalizedError {
                public var errorDescription: String?
            }

            do {
                guard let tiffData = image.tiffRepresentation,
                      let bitmap = NSBitmapImageRep(data: tiffData) else {
                    throw ImageWriteError(errorDescription: "Failed to convert image")
                }

                let imageType = UTType(filenameExtension: url.pathExtension)

                if imageType == .png {
                    if let pngData = bitmap.representation(using: .png, properties: [:]) {
                        try pngData.write(to: url)
                    } else {
                        throw ImageWriteError(errorDescription: "Failed to convert image to PNG")
                    }
                } else if imageType == .jpeg {
                    if let jpegData = bitmap.representation(using: .jpeg, properties: [:]) {
                        try jpegData.write(to: url)
                    } else {
                        throw ImageWriteError(errorDescription: "Failed to convert image to JPEG")
                    }
                } else {
                    throw ImageWriteError(errorDescription: "Unknown image format")
                }
            } catch {
                let alert = NSAlert()
                alert.alertStyle = .warning
                alert.messageText = "Failed to save image."
                alert.informativeText = "Error: \(error.localizedDescription)"
                alert.beginSheetModal(for: window, completionHandler: nil)
            }
        })
    }

    private func replaceImage() {
        if let window = blockStorage.textView?.window {
            selectImage(in: window)
        }
    }

    private func changeImagePosition(from oldPosition: ImagePosition, to newPosition: ImagePosition) {
        attachmentCell.position = newPosition
        invalidateLayout()

        let textView = blockStorage.textView!
        textView.window?.invalidateCursorRects(for: textView)
        attachmentCell.position = newPosition

        if let undoManager = textView.undoManager {
            undoManager.beginUndoGrouping()

            undoManager.registerUndo(withTarget: self, handler: {block in
                block.changeImagePosition(from: newPosition, to: oldPosition)
            })

            undoManager.endUndoGrouping()
        }
    }

    private func setImagePosition(_ newPosition: ImagePosition) {
        let oldPosition = attachmentCell.position

        if oldPosition != newPosition {
            blockStorage.textView.breakUndoCoalescing()
            changeImagePosition(from: oldPosition, to: newPosition)
        }
    }
}


fileprivate extension NSImage {
    struct ImageWriteError: Error {
        let localizedDescription: String
    }

    func write(to url: URL) throws {
        guard let tiffData = tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            throw ImageWriteError(localizedDescription: "Failed to convert image")
        }

        let imageType = UTType(filenameExtension: url.pathExtension)
        let imageData: Data

        if imageType == .png {
            if let pngData = bitmap.representation(using: .png, properties: [:]) {
                imageData = pngData
            } else {
                throw ImageWriteError(localizedDescription: "Failed to convert image to PNG")
            }
        } else if imageType == .jpeg {
            if let jpegData = bitmap.representation(using: .jpeg, properties: [:]) {
                imageData = jpegData
            } else {
                throw ImageWriteError(localizedDescription: "Failed to convert image to JPEG")
            }
        } else {
            throw ImageWriteError(localizedDescription: "Unknown image format")
        }

        try imageData.write(to: url, options: .withoutOverwriting)
    }
}

fileprivate class ImagePlaceholderView : NSView {
    static private let defaultColor = CGColor(srgbRed: 0.95, green: 0.95, blue: 0.95, alpha: 1)
    static private let mouseOverColor = CGColor(srgbRed: 0.9, green: 0.9, blue: 0.9, alpha: 1)
    static private let mouseDownColor = CGColor(srgbRed: 0.8, green: 0.8, blue: 0.8, alpha: 1)

    static private let iconImage = {() -> NSImage in
        guard let icon = NSImage(systemSymbolName: "photo", accessibilityDescription: nil) else {
            return NSImage()
        }

        return icon.tinted(with: NSColor.Monochrome.LightGray)
    }()

    static private let labelText = {() -> NSAttributedString in
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byTruncatingTail

        let attributes: [NSAttributedString.Key : Any] = [
            .foregroundColor : NSColor.Monochrome.LightGray,
            .font : NSFont.systemFont(ofSize: 14),
            .paragraphStyle : paragraphStyle
        ]

        return NSAttributedString(string: "Add an image", attributes: attributes)
    }()

    private unowned let block: ImageBlock
    private let iconView: NSImageView
    private let label: NSTextField

    init(block: ImageBlock) {
        self.block = block
        self.iconView = NSImageView(image: ImagePlaceholderView.iconImage)
        self.label = NSTextField(labelWithAttributedString: ImagePlaceholderView.labelText)

        super.init(frame: NSRect())
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true

        if let layer = self.layer {
            layer.backgroundColor = ImagePlaceholderView.defaultColor
            layer.cornerRadius = 4
        }

        label.translatesAutoresizingMaskIntoConstraints = false
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.imageScaling = .scaleProportionallyUpOrDown

        addSubview(iconView)
        addSubview(label)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            iconView.heightAnchor.constraint(equalTo: heightAnchor, constant: -8),
            iconView.widthAnchor.constraint(equalTo: iconView.heightAnchor),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),

            label.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
            label.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -8),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        registerForDraggedTypes([
            .png,
            NSPasteboard.PasteboardType(UTType.jpeg.description),
            .tiff,
            .pdf,
            .URL
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        for trackingArea in self.trackingAreas {
            removeTrackingArea(trackingArea)
        }

        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeAlways]
        let trackingArea = NSTrackingArea(rect: self.bounds, options: options, owner: self, userInfo: nil)

        addTrackingArea(trackingArea)
    }

    override func mouseEntered(with event: NSEvent) {
        layer?.backgroundColor = ImagePlaceholderView.mouseOverColor
    }

    override func mouseExited(with event: NSEvent) {
        layer?.backgroundColor = ImagePlaceholderView.defaultColor
    }

    override func mouseDown(with event: NSEvent) {
        guard let window = self.window else {
            return
        }

        layer?.backgroundColor = ImagePlaceholderView.mouseDownColor

        while true {
            guard let event = window.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]), event.type == .leftMouseUp else {
                continue
            }

            let location = convert(event.locationInWindow, from: nil)

            if bounds.contains(location) {
                layer?.backgroundColor = ImagePlaceholderView.mouseOverColor
                block.selectImage(in: window)
            } else {
                layer?.backgroundColor = ImagePlaceholderView.defaultColor
            }

            return
        }
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        return .copy
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let image = NSImage(pasteboard: sender.draggingPasteboard) else {
            NSSound.beep()
            return false
        }

        let textView = block.blockStorage.textView!
        textView.breakUndoCoalescing()
        block.setImage(image: image)
        textView.needsDisplay = true

        return true
    }
}

fileprivate class ImageResizeBar : NSView {
    private unowned var block: ImageBlock
    private var direction: CGFloat

    enum Position {
        case left
        case right
    }

    init(block: ImageBlock, position: Position) {
        self.block = block
        self.direction = position == .right ? 1 : -1
        super.init(frame: NSRect())

        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true

        if let layer = self.layer {
            layer.backgroundColor = CGColor(srgbRed: 0.75, green: 0.75, blue: 0.75, alpha: 1)
            layer.borderColor = CGColor(srgbRed: 0.95, green: 0.95, blue: 0.95, alpha: 1)
            layer.borderWidth = 1
            layer.cornerRadius = 4
        }

        setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        setContentHuggingPriority(.defaultHigh, for: .vertical)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: NSSize {
        return NSSize(width: 8, height: 80)
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .resizeLeftRight)
    }

    private func didFinishResizing(with event: NSEvent) {
        let imageView = superview as! ImageContentView
        let location = imageView.convert(event.locationInWindow, to: nil)

        if imageView.frame.contains(location) {
            imageView.animateSubviews(setHidden: false)
        } else {
            imageView.animateSubviews(setHidden: true)
        }
    }

    override func mouseDown(with event: NSEvent) {
        guard let window = self.window else {
            return
        }

        let attachmentCell = block.attachment.attachmentCell as! ImageBlockTextAttachmentCell
        let blockStorage = block.blockStorage
        let textView = blockStorage.textView!

        blockStorage.updateBlock(block)
        let blockRange = block.range

        let initialSize = attachmentCell.imageSize
        let aspectRatio = initialSize.height / initialSize.width
        let maxWidth = textView.frame.width - (textView.textContainerInset.width * 2) - 8
        let minWidth: CGFloat = 80

        var lastSize = NSSize(width: min(initialSize.width, maxWidth), height: 0)
        var lastLocation = event.locationInWindow

        while true {
            guard let event = window.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]) else {
                continue
            }

            if event.type == .leftMouseUp {
                if lastSize != initialSize {
                    block.blockStorage.textView.breakUndoCoalescing()
                    block.registerUndoResizeImage(from: initialSize, to: lastSize)
                }

                return didFinishResizing(with: event)
            }

            let location = event.locationInWindow
            let distance = (lastLocation.x - location.x) * direction
            let newWidth = max(min(lastSize.width - distance, maxWidth), minWidth)

            if newWidth == lastSize.width {
                continue
            }

            lastLocation = location
            lastSize = NSSize(width: newWidth, height: newWidth * aspectRatio)
            attachmentCell.imageSize = lastSize

            for layoutManager in blockStorage.layoutManagers {
                layoutManager.invalidateLayout(forCharacterRange: blockRange, actualCharacterRange: nil)
            }

            textView.needsDisplay = true
        }
    }
}

fileprivate class ImageContentView : NSView {
    private unowned let block: ImageBlock
    let imageView: NSImageView
    let menuButton: ImageBlockMenuButton
    let leftResizeBar: ImageResizeBar
    let rightResizeBar: ImageResizeBar

    var xPositionConstraint: NSLayoutConstraint?
    var sizeConstraints: (height: NSLayoutConstraint, width: NSLayoutConstraint)?
    var subviewsHidden: Bool = true
    var animationTick = 0

    init(block: ImageBlock, image: NSImage, position: ImagePosition) {
        self.block = block
        self.imageView = NSImageView(image: image)
        self.menuButton = ImageBlockMenuButton(parentBlock: block)
        self.leftResizeBar = ImageResizeBar(block: block, position: .left)
        self.rightResizeBar = ImageResizeBar(block: block, position: .right)
        super.init(frame: NSRect())

        translatesAutoresizingMaskIntoConstraints = false
        subviews = [imageView, menuButton, leftResizeBar, rightResizeBar]

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.imageScaling = .scaleProportionallyUpOrDown

        menuButton.isHidden = true
        leftResizeBar.isHidden = true
        rightResizeBar.isHidden = true

        let size = image.size
        let heightConstarint = imageView.heightAnchor.constraint(equalToConstant: size.height)
        let widthConsraint = imageView.widthAnchor.constraint(equalToConstant: size.width)
        let positionConstraint = imagePositionConstraint(for: position)

        NSLayoutConstraint.activate([
            heightConstarint,
            widthConsraint,
            positionConstraint,
            imageView.centerYAnchor.constraint(equalTo: centerYAnchor),

            menuButton.topAnchor.constraint(equalTo: topAnchor),
            menuButton.trailingAnchor.constraint(equalTo: imageView.trailingAnchor),

            leftResizeBar.leadingAnchor.constraint(equalTo: imageView.leadingAnchor),
            leftResizeBar.centerYAnchor.constraint(equalTo: imageView.centerYAnchor),
            rightResizeBar.centerYAnchor.constraint(equalTo: imageView.centerYAnchor),
            rightResizeBar.trailingAnchor.constraint(equalTo: imageView.trailingAnchor)
        ])

        sizeConstraints = (heightConstarint, widthConsraint)
        xPositionConstraint = positionConstraint
    }

    private func imagePositionConstraint(for position: ImagePosition) -> NSLayoutConstraint {
        switch position {
        case .left:
            return imageView.leadingAnchor.constraint(equalTo: leadingAnchor)

        case .center:
            return imageView.centerXAnchor.constraint(equalTo: centerXAnchor)

        case .right:
            return imageView.trailingAnchor.constraint(equalTo: trailingAnchor)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func replaceImage(with image: NSImage) {
        imageView.image = image
    }

    func setImageSize(_ size: NSSize) {
        if let constraints = sizeConstraints {
            constraints.height.constant = size.height
            constraints.width.constant = size.width
        }
    }

    func setImagePosition(_ position: ImagePosition) {
        xPositionConstraint?.isActive = false

        let newPositionConstraint = imagePositionConstraint(for: position)
        newPositionConstraint.isActive = true
        xPositionConstraint = newPositionConstraint

        animateSubviews(setHidden: true)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let converted = convert(point, from: superview!)

        if menuButton.frame.contains(converted) {
            return menuButton
        } else if leftResizeBar.frame.contains(converted) {
            return leftResizeBar
        } else if rightResizeBar.frame.contains(converted) {
            return rightResizeBar
        } else if imageView.frame.contains(converted) {
            return self
        } else {
            return nil
        }
    }

    override func resetCursorRects() {
        addCursorRect(imageView.frame, cursor: .pointingHand)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        let trackingAreas = self.trackingAreas
        let imageViewFrame = imageView.frame

        if let area = trackingAreas.first {
            if area.rect == imageViewFrame {
                return
            }

            removeTrackingArea(area)
        }

        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeAlways]
        let trackingArea = NSTrackingArea(rect: imageViewFrame, options: options, owner: self, userInfo: nil)
        addTrackingArea(trackingArea)
    }

    override func layout() {
        super.layout()
        updateTrackingAreas()
    }

    func animateSubviews(setHidden hidden: Bool) {
        animationTick += 1

        let currentTick = animationTick
        let startAlphaValue: CGFloat = hidden ? 1 : 0
        let endAlphaValue: CGFloat = hidden ? 0 : 1

        menuButton.isHidden = false
        leftResizeBar.isHidden = false
        rightResizeBar.isHidden = false

        menuButton.alphaValue = startAlphaValue
        leftResizeBar.alphaValue = startAlphaValue
        rightResizeBar.alphaValue = startAlphaValue

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.5
            self.menuButton.animator().alphaValue = endAlphaValue
            self.leftResizeBar.animator().alphaValue = endAlphaValue
            self.rightResizeBar.animator().alphaValue = endAlphaValue
        } completionHandler: {
            if self.animationTick == currentTick && hidden {
                self.menuButton.isHidden = true
                self.leftResizeBar.isHidden = true
                self.rightResizeBar.isHidden = true
            }
        }
    }

    override func mouseEntered(with event: NSEvent) {
        animateSubviews(setHidden: false)
    }

    override func mouseExited(with event: NSEvent) {
        animateSubviews(setHidden: true)
    }

    override func mouseDown(with mouseDownEvent: NSEvent) {
        guard let window = self.window else {
            return
        }

        let block = self.block
        let blockStorage = block.blockStorage
        let textView = blockStorage.textView!
        let mouseDownLocation = mouseDownEvent.locationInWindow

        blockStorage.updateBlock(block)
        let blockIndex = block.index

        while true {
            guard let event = window.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]) else {
                continue
            }

            let locationInWindow = event.locationInWindow

            if event.type == .leftMouseDragged {
                if locationInWindow.distance(from: mouseDownLocation) > 2 {
                    textView.setSelectedBlocks(blockIndex ..< blockIndex + 1)
                    textView.blockHoverViewDidStartDragging(with: event)
                    return
                }
            } else {
                let location = convert(locationInWindow, from: nil)

                if bounds.contains(location) {
                    textView.setSelectedBlocks(blockIndex ..< blockIndex + 1)
                }

                return
            }
        }
    }
}

fileprivate class ImageContainerView: NSView {
    private unowned var block: ImageBlock
    private var position: ImagePosition

    let image: NSImage?
    var view: NSView

    init(block: ImageBlock, image: NSImage?, position: ImagePosition) {
        self.block = block
        self.position = .center
        self.image = image

        if let image = image {
            self.view = ImageContentView(block: block, image: image, position: position)
        } else {
            self.view = ImagePlaceholderView(block: block)
        }

        super.init(frame: NSRect())
        translatesAutoresizingMaskIntoConstraints = false
        addSubviewWithConstraints(view)
    }

    private func addSubviewWithConstraints(_ view: NSView) {
        addSubview(view)

        NSLayoutConstraint.activate([
            view.heightAnchor.constraint(equalTo: heightAnchor, constant: -30),
            view.widthAnchor.constraint(equalTo: widthAnchor, constant: -10),
            view.centerXAnchor.constraint(equalTo: centerXAnchor),
            view.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    func restorePlaceholderView() {
        position = .center

        if view is ImagePlaceholderView {
            return
        }

        view.removeFromSuperview()
        view = ImagePlaceholderView(block: block)
        addSubviewWithConstraints(view)
    }

    func replaceImage(with image: NSImage) {
        if let imageView = view as? ImageContentView {
            imageView.replaceImage(with: image)
        } else {
            view.removeFromSuperview()
            view = ImageContentView(block: block, image: image, position: position)
            addSubviewWithConstraints(view)
        }
    }

    func setImageSize(_ size: NSSize) {
        if let imageView = view as? ImageContentView {
            imageView.setImageSize(size)
        }
    }

    func setImagePosition(_ position: ImagePosition) {
        if let imageView = view as? ImageContentView {
            imageView.setImagePosition(position)
            self.position = position
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let converted = superview!.convert(point, to: self)

        if view.frame.contains(converted) {
            return view.hitTest(converted)
        } else {
            return nil
        }
    }
}

enum ImagePosition: Int, Codable {
    case left
    case center
    case right
}

fileprivate enum ImageBlockMenuAction: Int, RawRepresentable {
    case delete
    case duplicate
    case replace
    case download
    case alignLeft
    case alignCenter
    case alignRight
}

final class ImageBlockMenuButton : NSButton {
    var imageSize = NSSize(width: 16, height: 16)

    init(parentBlock: ImageBlock) {
        let image = NSImage(systemSymbolName: "ellipsis.rectangle.fill", accessibilityDescription: nil)!
        let imageSize = image.size
        let aspectRatio = imageSize.height / imageSize.width

        self.imageSize = NSSize(width: 24, height: 24 * aspectRatio)
        super.init(frame: NSRect())

        self.translatesAutoresizingMaskIntoConstraints = false
        self.frame.size.height = frame.size.width * aspectRatio
        self.image = image.tinted(with: NSColor.Monochrome.LightGray)

        self.setButtonType(.momentaryChange)
        self.action = #selector(popUpMenu(_:))
        self.target = self
        self.isBordered = false
        self.imageScaling = .scaleProportionallyUpOrDown
        self.menu = parentBlock.contextMenu()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc func popUpMenu(_ : Any?) {
        if let menu = self.menu, let event = NSApp.currentEvent {
            NSMenu.popUpContextMenu(menu, with: event, for: self)
        }
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .arrow)
    }

    override var intrinsicContentSize: NSSize {
        return imageSize
    }
}

class ImageBlockTextAttachmentCell : NSTextAttachmentCell {
    fileprivate var overlayView: ImageContainerView? = nil

    private var overlayConstraints: (height:   NSLayoutConstraint,
                                     top:      NSLayoutConstraint,
                                     leading:  NSLayoutConstraint,
                                     trailing: NSLayoutConstraint)? = nil

    public unowned var block: ImageBlock!
    public var imageSize = NSSize()

    public override var image: NSImage? {
        didSet {
            if let image = self.image {
                imageSize = image.size
                overlayView?.replaceImage(with: image)
            } else {
                overlayView?.restorePlaceholderView()
            }
        }
    }

    fileprivate var position: ImagePosition = .center {
        didSet {
            overlayView?.setImagePosition(position)
        }
    }

    private func overlayFrameForImage(withSize imageSize: NSSize, maxWidth: CGFloat) -> NSRect {
        var imageSize = imageSize

        if maxWidth < imageSize.width {
            let ratio = maxWidth / imageSize.width
            imageSize.width = maxWidth
            imageSize.height = imageSize.height * ratio
        }

        overlayView!.setImageSize(imageSize)
        return NSRect(x: 0, y: 0, width: maxWidth, height: imageSize.height + 30)
    }

    override func cellFrame(for textContainer: NSTextContainer, proposedLineFragment: NSRect, glyphPosition: NSPoint, characterIndex: Int) -> NSRect {
        if overlayView == nil {
            let textView = block.blockStorage.textView!
            let overlay = ImageContainerView(block: block, image: image, position: position)
            let height   = overlay.heightAnchor.constraint(equalToConstant: 100)
            let top      = overlay.topAnchor.constraint(equalTo: textView.topAnchor, constant: 0)
            let leading  = overlay.leadingAnchor.constraint(equalTo: textView.leadingAnchor, constant: 0)
            let trailing = overlay.trailingAnchor.constraint(equalTo: textView.trailingAnchor, constant: 0)

            textView.addSubview(overlay)

            NSLayoutConstraint.activate([height, top, leading, trailing])
            overlayConstraints = (height, top, leading, trailing)
            overlayView = overlay
        }

        let lineWidth = proposedLineFragment.size.width - 8

        if image == nil {
            return NSRect(x: 0, y: 0, width: lineWidth, height: 70)
        } else {
            return overlayFrameForImage(withSize: imageSize, maxWidth: lineWidth)
        }
    }

    override func draw(withFrame cellFrame: NSRect, in controlView: NSView?) {
        guard let textView = controlView as? TextView,
              let constraints = overlayConstraints else {
            return
        }

        let inset = textView.textContainerInset

        constraints.top.constant = cellFrame.origin.y
        constraints.height.constant = cellFrame.size.height
        constraints.leading.constant = inset.width
        constraints.trailing.constant = -inset.width
    }

    func removeSubviews() {
        if let view = self.overlayView {
            view.removeFromSuperview()
            overlayView = nil
            overlayConstraints = nil
        }
    }
}

fileprivate func blockStyle() -> StyleBuilder {
    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.paragraphSpacingBefore = 0
    paragraphStyle.paragraphSpacing = 0

    return StyleBuilder(attributes: [
        .paragraphStyle : paragraphStyle,
        .blockType : BlocksInfo.Types.image
    ])
}

fileprivate func insertAttachment(at range: NSRange, in storage: TextBlockStorage) -> NSRange {
    let baseString = String(UnicodeScalar(NSTextAttachment.character)!) + "\n"
    let adjustedRange = NSRange(location: range.location, length: baseString.utf16.count)
    let textView = storage.textView!

    textView.shouldChangeText(in: range, replacementString: baseString)
    storage.underlyingTextStorage.replaceCharacters(in: range, with: baseString)
    storage.edited([.editedCharacters], range: range, changeInLength: adjustedRange.length - range.length)
    textView.didChangeText()

    return adjustedRange
}
