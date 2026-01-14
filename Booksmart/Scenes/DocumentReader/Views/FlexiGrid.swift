import SwiftUI

struct FlexiGrid<BookContent: View, NotesContent: View, FlashcardsContent: View>: View {
	@EnvironmentObject var readerState: ReaderState
    
    var bookView: BookContent
    var notesView: NotesContent
    var flashcardsView: FlashcardsContent
    
    init(@ViewBuilder bookViewBuilder: () -> BookContent, @ViewBuilder notesViewBuilder: () -> NotesContent, @ViewBuilder flashcardsViewBuilder: () -> FlashcardsContent) {
        self.bookView = bookViewBuilder()
        self.notesView = notesViewBuilder()
        self.flashcardsView = flashcardsViewBuilder()
    }
    
    var subsceneLayout: SubsceneLayoutManager {
        readerState.subsceneLayout
    }
    
    func getFlexigridPosition(_ scene: ReaderSubScene) -> [FlexigridPosition] {
        if !subsceneLayout.contains(scene)
        {
            return [.hidden]
        }
        
        if subsceneLayout.count == 1
        {
            return [.full]
        }
        
        if subsceneLayout.count == 2
        {
            if scene == .book
            {
                return subsceneLayout.layoutOrientation == .horizontal ? [.left] : [.top]
            }
            else if scene == .notes
            {
                if subsceneLayout.contains(.book)
                {
                    return subsceneLayout.layoutOrientation == .horizontal ? [.right] : [.bottom]
                }
                
                return subsceneLayout.layoutOrientation == .horizontal ? [.left] : [.top]
            }
            else // then scene == .flashcards ...
            {
                return subsceneLayout.layoutOrientation == .horizontal ? [.right] : [.bottom]
            }
        }
        
        if subsceneLayout.count == 3
        {
            if scene == .book
            {
                return subsceneLayout.layoutOrientation == .horizontal ? [.left] : [.top]
            }
            else if scene == .notes
            {
                return subsceneLayout.layoutOrientation == .horizontal ? [.top, .right] : [.bottom, .left]
            }
            else // then scene == .flashcards ...
            {
                return subsceneLayout.layoutOrientation == .horizontal ? [.bottom, .right] : [.bottom, .right]
            }
        }
        
        return [.hidden]
    }
	
	var body: some View {
		GeometryReader { geometry in
            bookView
                .flexigridPosition(getFlexigridPosition(.book), size: geometry.size)
            
            notesView
                .flexigridPosition(getFlexigridPosition(.notes), size: geometry.size)
            
            flashcardsView
                .flexigridPosition(getFlexigridPosition(.flashcards), size: geometry.size)
		}
	}
}

enum FlexigridPosition {
    case top
    case bottom
    case left
    case right
    case full
    case hidden
}

struct FlexigridPositionManager: ViewModifier {
    var flexigridPosition: [FlexigridPosition]
    var geoSize: NSSize
    
    func body(content: Content) -> some View {
        content
            .frame(width: getWidth(), height: getHeight())
            .position(x: getX(), y: getY())
    }
    
    func getWidth() -> Double {
        assert(flexigridPosition.count > 0 && flexigridPosition.count <= 2)
        
        if flexigridPosition.contains(.hidden)
        {
            return 1.0
        }
        
        if flexigridPosition.contains(.left) || flexigridPosition.contains(.right)
        {
            return geoSize.width / 2.0
        }
        
        return geoSize.width
    }
    
    func getHeight() -> Double {
        assert(flexigridPosition.count > 0 && flexigridPosition.count <= 2)
        
        if flexigridPosition.contains(.hidden)
        {
            return 1.0
        }
        
        if flexigridPosition.contains(.top) || flexigridPosition.contains(.bottom)
        {
            return geoSize.height / 2.0
        }
        
        return geoSize.height
    }
    
    func getX() -> Double {
        assert(flexigridPosition.count > 0 && flexigridPosition.count <= 2)
        
        if flexigridPosition.contains(.hidden)
        {
            return -500.0
        }
        
        if flexigridPosition.contains(.left)
        {
            return geoSize.width / 4.0
        }
        
        if flexigridPosition.contains(.right)
        {
            return geoSize.width * 0.75
        }
        
        return geoSize.width / 2.0
    }
    
    func getY() -> Double {
        assert(flexigridPosition.count > 0 && flexigridPosition.count <= 2)
        
        if flexigridPosition.contains(.hidden)
        {
            return -500.0
        }
        
        if flexigridPosition.contains(.top)
        {
            return geoSize.height / 4.0
        }
        
        if flexigridPosition.contains(.bottom)
        {
            return geoSize.height * 0.75
        }
        
        return geoSize.height / 2.0
    }
    
}

extension View {
    func flexigridPosition(_ flexigridPosition: [FlexigridPosition], size: NSSize) -> some View {
        modifier(FlexigridPositionManager(flexigridPosition: flexigridPosition, geoSize: size))
    }
}
