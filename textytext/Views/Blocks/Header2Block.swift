import Cocoa

fileprivate func blockStyle() -> StyleBuilder {
    return StyleBuilder(
        color: NSColor.Grayscale.Title,
        fontSize: 26.0,
        lineSpacing: 7.0,
        blockType: .header2
    )
}

class Header2Block: Block {
    typealias Coded = Block.Coded

    public init(owner: TextBlockStorage, range: NSRange, index: Int = 0) {
        super.init(owner: owner, type: .header2, style: blockStyle(), range: range, index: index)
    }

    public init(from coded: Coded, owner: TextBlockStorage, offset: Int, index: Int) throws {
        try super.init(owner: owner, type: .text, style: blockStyle(), data: coded.data, offset: offset, index: index)
    }

    required init(copy block: Block) {
        super.init(copy: block)
    }
}
