import AppKit

extension NSMenu {
    convenience init(items: [NSMenuItem]) {
        self.init()
        self.items = items
        self.allowsContextMenuPlugIns = false
    }
}
