import Foundation

class BlockUndoManager : UndoManager {
    override init() {
        super.init()
        groupsByEvent = false
    }

    override func undo() {
        if groupingLevel >= 1 {
            super.endUndoGrouping()
        }

        super.undo()
    }

    override func undoNestedGroup() {
        if groupingLevel >= 1 {
            super.endUndoGrouping()
        }

        super.undoNestedGroup()
    }

    public override func registerUndo(withTarget target: Any, selector: Selector, object anObject: Any?) {
        if groupingLevel == 0 {
            super.beginUndoGrouping()

            if isUndoing == false, isRedoing == false, let blockStorage = target as? TextBlockStorage {
                blockStorage.registerBlockStateUndoHandler()
            }
        }

        super.registerUndo(withTarget: target, selector: selector, object: anObject)
    }
}
