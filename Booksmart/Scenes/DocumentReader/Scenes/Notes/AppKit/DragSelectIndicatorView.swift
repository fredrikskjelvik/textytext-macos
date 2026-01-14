import Cocoa

/// The transparent light blue square that appears when you click on the textview and drag to select blocks
class DragSelectIndicatorView : NSView {
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true

        if let layer = self.layer {
            layer.backgroundColor = CGColor(srgbRed: 200/255, green: 225/255, blue: 255/255, alpha: 0.25)
            layer.borderColor = CGColor(srgbRed: 175/255, green: 200/255, blue: 255/255, alpha: 0.75)
            layer.borderWidth = 1
            layer.cornerRadius = 4
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
