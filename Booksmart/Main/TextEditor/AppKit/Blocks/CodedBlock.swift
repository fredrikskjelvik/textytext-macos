import Foundation

enum BlockCodingError: Error {
    case invalidData
    case invalidType
}

/// Top level enum for making blocks codeable. Each block type has it's own Codeable implementation and this is an enum with each block type
/// and it's codeable implementation as an associated value.
enum CodedBlock: Codable {
    private enum Keys: CodingKey {
        case type
        case coded
    }

    case text(TextBlock.Coded)
    case header1(Header1Block.Coded)
    case header2(Header2Block.Coded)
    case list(ListBlock.Coded)
    case orderedlist(OrderedListBlock.Coded)
    case image(ImageBlock.Coded)
    case codesnippet(CodeBlock.Coded)

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        let type = try container.decode(BlocksInfo.Types.self, forKey: .type)

        switch type {
        case .text:
            self = .text(try container.decode(TextBlock.Coded.self, forKey: .coded))

        case .header1:
            self = .header1(try container.decode(Header1Block.Coded.self, forKey: .coded))

        case .header2:
            self = .header2(try container.decode(Header2Block.Coded.self, forKey: .coded))

        case .list:
            self = .list(try container.decode(ListBlock.Coded.self, forKey: .coded))

        case .orderedlist:
            self = .orderedlist(try container.decode(OrderedListBlock.Coded.self, forKey: .coded))

        case .image:
            self = .image(try container.decode(ImageBlock.Coded.self, forKey: .coded))

        case .codesnippet:
            self = .codesnippet(try container.decode(CodeBlock.Coded.self, forKey: .coded))

        default:
            throw BlockCodingError.invalidType
        }
    }

    init(_ block: Block) throws {
        switch block.type
        {
        case .text:
            self = .text(TextBlock.Coded(block))

        case .header1:
            self = .header1(Header1Block.Coded(block))

        case .header2:
            self = .header2(Header2Block.Coded(block))

        case .list:
            self = .list(try ListBlock.Coded(block))

        case .orderedlist:
            self = .orderedlist(try OrderedListBlock.Coded(block))

        case .image:
            self = .image(try ImageBlock.Coded(block))

        case .codesnippet:
            self = .codesnippet(CodeBlock.Coded(block))

        default:
            throw BlockCodingError.invalidType
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Keys.self)

        switch self {
        case .text(let coded):
            try container.encode(BlocksInfo.Types.text, forKey: .type)
            try container.encode(coded, forKey: .coded)

        case .header1(let coded):
            try container.encode(BlocksInfo.Types.header1, forKey: .type)
            try container.encode(coded, forKey: .coded)

        case .header2(let coded):
            try container.encode(BlocksInfo.Types.header2, forKey: .type)
            try container.encode(coded, forKey: .coded)

        case .list(let coded):
            try container.encode(BlocksInfo.Types.list, forKey: .type)
            try container.encode(coded, forKey: .coded)

        case .orderedlist(let coded):
            try container.encode(BlocksInfo.Types.orderedlist, forKey: .type)
            try container.encode(coded, forKey: .coded)

        case .image(let coded):
            try container.encode(BlocksInfo.Types.image, forKey: .type)
            try container.encode(coded, forKey: .coded)

        case .codesnippet(let coded):
            try container.encode(BlocksInfo.Types.codesnippet, forKey: .type)
            try container.encode(coded, forKey: .coded)
        }
    }
}
