import Cocoa

extension NSNotification.Name {

    // MARK: Notifications related to the word processor

    static let DidRequestApplyInlineStyling: NSNotification.Name = .init("DidRequestApplyInlineStyling")
    static let DidRequestChangeBlockType: NSNotification.Name = .init("DidRequestChangeBlockType")
    
    // MARK: Notifications related to the ebook reader

    static let DidRequestUndoPageHop: NSNotification.Name = .init("DidRequestUndoPageHop")
    static let DidRequestRedoPageHop: NSNotification.Name = .init("DidRequestRedoPageHop")
    
    static let DidRequestZoomIn: NSNotification.Name = .init("DidRequestZoomIn")
    static let DidRequestZoomOut: NSNotification.Name = .init("DidRequestZoomOut")

}
