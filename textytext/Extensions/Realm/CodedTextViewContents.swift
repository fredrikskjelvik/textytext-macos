import SwiftUI
import RealmSwift

/// A class that contains the text contents of one text view (i.e. one chapter or one flashcard question, hint, or answer) and is able to store it in Realm by encoding it into JSON and saving it as Data using FailableCustomPersistable.
final class CodedTextViewContents: Equatable, FailableCustomPersistable {
    let data: Data
    let blocks: [CodedBlock]
    
    /// The subset of blocks that are string based. This list is used for search.
    lazy var textBlocks: [StringBasedBlockCoded] = {
        var textBlocks = [StringBasedBlockCoded]()
        
        for block in blocks
        {
            switch block
            {
            case .text(let coded):
                textBlocks.append(coded as StringBasedBlockCoded)
            case .header1(let coded):
                textBlocks.append(coded as StringBasedBlockCoded)
            case .header2(let coded):
                textBlocks.append(coded as StringBasedBlockCoded)
            case .list(let coded):
                textBlocks.append(coded as StringBasedBlockCoded)
            case .orderedlist(let coded):
                textBlocks.append(coded as StringBasedBlockCoded)
            case .codesnippet(let coded):
                textBlocks.append(coded as StringBasedBlockCoded)
            default:
                break
            }
        }
        
        return textBlocks
    }()
    
    init(data: Data) throws {
        self.data = data
        
        let decoder = JSONDecoder()
            decoder.dataDecodingStrategy = .deferredToData
        
        do
        {
            self.blocks = try decoder.decode([CodedBlock].self, from: data)
        }
        catch
        {
            throw CustomError.FailedToConvertBlockDataToBlocks
        }
    }
    
    init(blocks: [CodedBlock]) throws {
        self.blocks = blocks
        
        let encoder = JSONEncoder()
            encoder.dataEncodingStrategy = .deferredToData
        
        do
        {
            let encoded = try encoder.encode(blocks)
            self.data = encoded
        }
        catch
        {
            throw error
        }
    }
    
    convenience init?(string: String) {
        let textBlock = Block.Coded(string: string)
        let block = CodedBlock.text(textBlock)
        
        try? self.init(blocks: [block])
    }
    
    // MARK: Conformance to Equatable
    
    static func == (lhs: CodedTextViewContents, rhs: CodedTextViewContents) -> Bool {
        return lhs.data == rhs.data
    }
    
    // MARK: Conformance to FailableCustomPersistable
    // Makes it possible to store this type in a Realm object. Is stored under the hood as Data, but
    // is accessed as CodedBlock's
    
    public typealias PersistedType = Data
    
    public convenience init?(persistedValue: Data) {
        do {
            try self.init(data: persistedValue)
        } catch {
            return nil
        }
    }
    
    public var persistableValue: Data {
        return self.data
    }
}
