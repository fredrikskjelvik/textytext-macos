import Cocoa

/// The blue line that appears when dragging something (e.g. a block, image) at the location where it will be dropped if you release
/// the mouse at that moment.
class DraggedBlockDropIndicator : NSView {
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true

        if let layer = self.layer
        {
            layer.backgroundColor = CGColor(srgbRed: 0, green: 145 / 255, blue: 248 / 255, alpha: 0.8)
            layer.cornerRadius = frame.height / 2
        }
    }

    public required init?(coder: NSCoder) {
        return nil
    }
}
