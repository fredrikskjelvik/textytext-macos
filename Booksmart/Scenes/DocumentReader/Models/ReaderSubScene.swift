import Foundation

/// Orientation to lay out subscenes
enum Orientation {
    case horizontal
    case vertical
}

/// The three subcomponents in the document reader scene
enum ReaderSubScene {
    case book
    case notes
    case flashcards
}

/// Contains state (+ methods for manipulating) about which subcomponents/subscenes to show and which orientation to show them in.
struct SubsceneLayoutManager {
    var showing: [ReaderSubScene]
    var layoutOrientation: Orientation = .horizontal
    
    init(showing: [ReaderSubScene]) {
        self.showing = showing
    }
    
    // MARK: Getters
    
    func contains(_ subscene: ReaderSubScene) -> Bool {
        return showing.contains(subscene)
    }
    
    var count: Int {
        return showing.count
    }
    
    // MARK: Setters
    
    mutating func toggle(_ subscene: ReaderSubScene) {
        if showing.contains(subscene) == false
        {
            showing.append(subscene)
        }
        else if showing.count > 1
        {
            showing.removeAll(where: { $0 == subscene })
        }
    }
    
    mutating func unhide(_ subscene: ReaderSubScene) {
        if showing.contains(subscene) == false
        {
            showing.append(subscene)
        }
    }
    
    mutating func show(subscenes: [ReaderSubScene]) {
        showing = subscenes
    }
    
    mutating func switchOrientation() {
        layoutOrientation = layoutOrientation == .horizontal ? .vertical : .horizontal
    }
}
