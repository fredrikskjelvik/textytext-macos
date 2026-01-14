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

protocol SearchResult {
    var id: UUID { get }
    var block: StringBasedBlockCoded { get }
    var outline: OutlineItem { get }
    var resultTypeLabel: String { get }
    
    func goToResult(readerState: ReaderState)
}

extension SearchResult {
    var resultTypeLabel: String {
        if self as? NoteSearchResult != nil
        {
            return "Notes"
        }
        else if self as? FlashcardSearchResult != nil
        {
            return "Flashcards"
        }
        else
        {
            return "?"
        }
    }
}

struct NoteSearchResult: SearchResult {
    let id: UUID = UUID()
    let block: StringBasedBlockCoded
    let outline: OutlineItem
    let blockIndex: Int = 0
    
    func goToResult(readerState: ReaderState) {
        readerState.setChapterInSubState(NotesState.self, outlineItem: outline)
    }
}

struct FlashcardSearchResult: SearchResult {
    let id: UUID = UUID()
    let block: StringBasedBlockCoded
    let outline: OutlineItem
    let flashcard: FlashcardDB
    let field: FlashcardField
    
    func goToResult(readerState: ReaderState) {
        readerState.goToFlashcard(outlineItem: outline, flashcard: flashcard, flashcardField: field)
    }
}

class ContentSearcher: ObservableObject {
    let outlineContainer: OutlineContainer
    
    init(outlineContainer: OutlineContainer) {
        self.outlineContainer = outlineContainer
    }
    
    var activeSearchCapabilities: [ReaderSubScene] = []
    var possibleSearchResults: [ReaderSubScene: [SearchResult]] = [:]
    var returnedSearchResults: [ReaderSubScene: [SearchResult]] = [:]
    
    func addSearchCapability(note: NoteDB) {
        if activeSearchCapabilities.contains(.notes) {
            return
        }
        activeSearchCapabilities.append(.notes)
        
        var possibleNoteSearchResults = [SearchResult]()
        
        for noteChapter in note.noteChapters
        {
            guard
                let contents = noteChapter.contents,
                let chapter = noteChapter.outlineItem?.chapter,
                let outline = outlineContainer.getOutlineItem(.chapter(chapter))
            else { continue }
            
            for block in contents.textBlocks
            {
                possibleNoteSearchResults.append(NoteSearchResult(block: block, outline: outline))
            }
        }
        
        possibleSearchResults[.notes] = possibleNoteSearchResults
    }
    
    func addSearchCapability(flashcards: [FlashcardDB]) {
        if activeSearchCapabilities.contains(.flashcards) {
            return
        }
        activeSearchCapabilities.append(.flashcards)
        
        var possibleFlashcardSearchResults = [SearchResult]()
        
        for flashcard in flashcards
        {
            guard
                let chapter = flashcard.outlineItem?.chapter,
                let outline = outlineContainer.getOutlineItem(.chapter(chapter))
            else { continue }
            
            for flashcardField in [\FlashcardDB.question, \FlashcardDB.hint, \FlashcardDB.answer]
            {
                var field: FlashcardField = .question
                if flashcardField == \FlashcardDB.question
                {
                    field = .question
                }
                else if flashcardField == \FlashcardDB.hint
                {
                    field = .hint
                }
                else if flashcardField == \FlashcardDB.answer
                {
                    field = .answer
                }
                
                guard let textBlocks = flashcard[keyPath: flashcardField]?.textBlocks else { continue }
                
                for block in textBlocks
                {
                    possibleFlashcardSearchResults.append(FlashcardSearchResult(block: block, outline: outline, flashcard: flashcard, field: field))
                }
            }
        }
        
        possibleSearchResults[.flashcards] = possibleFlashcardSearchResults
    }
    
    func disableSearchCapability(for subscene: ReaderSubScene) {
        activeSearchCapabilities.removeAll(where: { $0 == subscene })
    }
    
    func searchAndReturnDict(for needle: String) -> [ReaderSubScene: [SearchResult]] {
        var results: [ReaderSubScene: [SearchResult]] = [:]
        
        for subview in activeSearchCapabilities
        {
            let searching = possibleSearchResults[subview]!
            let searched = searching.filter({ (result) in
                result.block.string.contains(needle)
            })
            
            results[subview] = searched
        }
        
        return results
    }
    
    func searchAndReturnList(for needle: String) -> [SearchResult] {
        var results = [SearchResult]()
        
        for subview in activeSearchCapabilities
        {
            let searching = possibleSearchResults[subview]!
            let searched = searching.filter({ (result) in
                result.block.string.contains(needle)
            })
            
            results.append(contentsOf: searched)
        }
        
        return results
    }
}

struct SearchReaderView: View {
    @EnvironmentObject var readerState: ReaderState
    @StateObject var contentSearcher: ContentSearcher
    
    init(outlineContainer: OutlineContainer) {
        self._contentSearcher = StateObject(wrappedValue: ContentSearcher(outlineContainer: outlineContainer))
    }
    
    @State private var searchInput = ""
    @State private var searchResults: [SearchResult] = []
    
    func performSearch(needle: String) {
        contentSearcher.addSearchCapability(note: readerState.document.note!)
        contentSearcher.addSearchCapability(flashcards: Array(readerState.document.flashcards))
        
        searchResults = contentSearcher.searchAndReturnList(for: needle)
    }
    
    var body: some View {
        VStack {
            Text("Search").font(.title)
            
            TextField("Search in notes/flashcards/book", text: $searchInput)
                .onSubmit {
                    performSearch(needle: searchInput)
                }
            
            Divider()
            
            List(searchResults, id: \.id) { result in
                Button(action: {
                    result.goToResult(readerState: readerState)
                }, label: {
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(result.block.string).font(.system(size: 18))
                            HStack(spacing: 6) {
                                Text(result.outline.label).font(.footnote)
                                Text(result.resultTypeLabel).font(.footnote)
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 22))
                    }
                })
                .buttonStyle(PlainButtonStyle())
            }
        }
        .onAppear {
//            contentSearcher.addSearchCapability(note: readerState.document.note!)
//            contentSearcher.addSearchCapability(flashcards: Array(readerState.document.flashcards))
        }
    }
    
}
