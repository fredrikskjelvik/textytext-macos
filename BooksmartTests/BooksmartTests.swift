import XCTest
@testable import Booksmart
import PDFKit

class BooksmartTests: XCTestCase {
    
    var storage: LocalStorageHandler!
    
    override func setUpWithError() throws {
        self.storage = try LocalStorageHandler()
    }
    
    override func tearDownWithError() throws {
        
    }
    
    // LocalStorageHandler
    
    func test_getPDF() throws {
        let book = try? self.storage.getBook(fileName: "pg2812.pdf")

        XCTAssertNotNil(book)

        let doc = PDFDocument(data: book!)

        XCTAssertNotNil(doc)
    }
    
    // Chapter
    
    func test_Chapter_initializer() throws {
        XCTAssertEqual(Chapter([2, 1]).indexes, [2, 1])
        XCTAssertEqual(Chapter([2]).indexes, [2])
        XCTAssertEqual(Chapter([]).indexes, [])
    }
    
    func test_Chapter_depth() throws {
        let rootDepth = Chapter([]).depth()
        let chapterDepth = Chapter([2]).depth()
        let subchapterDepth = Chapter([2, 5]).depth()
        
        XCTAssertEqual(rootDepth, 0)
        XCTAssertEqual(chapterDepth, 1)
        XCTAssertEqual(subchapterDepth, 2)
    }
    
    func test_Chapter_getPrefix() throws {
        let prefix1 = Chapter([2, 4]).getPrefix()
        let prefix2 = Chapter([2]).getPrefix()
        let prefix3 = Chapter([]).getPrefix()
        
        XCTAssertEqual(prefix1, "3.5")
        XCTAssertEqual(prefix2, "3")
        XCTAssertEqual(prefix3, "0")
    }
    
    func test_persisting() throws {
        let root = Chapter([])
        
        XCTAssertEqual(root.persistableValue, "")
        
        let initRootFromRealm = Chapter(persistedValue: "")
        
        XCTAssertNotNil(initRootFromRealm)
        
        if let root = initRootFromRealm {
            XCTAssertTrue(root.isRoot())
        }
    }
    
}



















//import XCTest
//@testable import Booksmart
//
//class TextViewStateTests: XCTestCase {
//
//    var textView: TextView!
//    var textViewState: TextViewState!
//
//    override func setUpWithError() throws {
//        let textStorage = NSTextStorage()
//        let layoutManager = NSLayoutManager()
//        textStorage.addLayoutManager(layoutManager)
//        let textContainer = NSTextContainer(containerSize: .zero)
//        layoutManager.addTextContainer(textContainer)
//
//        textView = TextView(frame: .zero, textContainer: textContainer)
//
//        let content = "Duis a dapibus ante.\nPraesent sed libero non sapien\nvulputate mollis eget placerat libero.\nQuisque elit est, maximus vitae ante ac, pellentesque facilisis nisi."
//        textView.textStorage!.setAttributedString(NSAttributedString(string: content))
//
//        textViewState = textView.state
//    }
//
//    override func tearDownWithError() throws {
//        // Put teardown code here. This method is called after the invocation of each test method in the class.
//    }
//
//    func test_getSpecificLineString() throws {
//        let firstLine = textViewState.paragraph.from(lineNumber: 0).getString()
//        let thirdLine = textViewState.paragraph.from(lineNumber: 2).getString()
//
//        XCTAssertEqual(firstLine, "Duis a dapibus ante.\n")
//        XCTAssertEqual(thirdLine, "vulputate mollis eget placerat libero.\n")
//    }
//
//    func test_getSpecificLineRange() throws {
//        let firstLine = textViewState.paragraph.from(lineNumber: 0).getRange()
//        let thirdLine = textViewState.paragraph.from(lineNumber: 2).getRange()
//
//        XCTAssertEqual(firstLine, NSRange(location: 0, length: 21))
//        XCTAssertEqual(thirdLine, NSRange(location: 52, length: 39))
//    }
//
//    func test_GetSpecificLine_AttributedSubstring() throws {
//        let firstLine = textViewState.paragraph.from(lineNumber: 0).getAttributedSubstring().string
//        let thirdLine = textViewState.paragraph.from(lineNumber: 2).getAttributedSubstring().string
//
//        XCTAssertEqual(firstLine, "Duis a dapibus ante.\n")
//        XCTAssertEqual(thirdLine, "vulputate mollis eget placerat libero.\n")
//    }
//
//    func test_current() throws {
//        // First paragraph
//        textView.setSelectedRange(NSRange(location: 0, length: 4))
//        let firstLineNumber = textViewState.paragraph.current().getLineNumber()
//        let firstLineRange = textViewState.paragraph.current().getRange()
//        let firstLineString = textViewState.paragraph.current().getString()
//        let firstLineAttributedSubstring = textViewState.paragraph.current().getAttributedSubstring().string
//
//        XCTAssertEqual(firstLineNumber, 0)
//        XCTAssertEqual(firstLineRange, NSRange(location: 0, length: 21))
//        XCTAssertEqual(firstLineString, "Duis a dapibus ante.\n")
//        XCTAssertEqual(firstLineAttributedSubstring, "Duis a dapibus ante.\n")
//
//        // Third paragraph
//        textView.setSelectedRange(NSRange(location: 56, length: 4))
//        let thirdLineNumber = textViewState.paragraph.current().getLineNumber()
//        let thirdLineRange = textViewState.paragraph.current().getRange()
//        let thirdLineString = textViewState.paragraph.current().getString()
//        let thirdLineAttributedSubstring = textViewState.paragraph.current().getAttributedSubstring().string
//
//        XCTAssertEqual(thirdLineNumber, 2)
//        XCTAssertEqual(thirdLineRange, NSRange(location: 52, length: 39))
//        XCTAssertEqual(thirdLineString, "vulputate mollis eget placerat libero.\n")
//        XCTAssertEqual(thirdLineAttributedSubstring, "vulputate mollis eget placerat libero.\n")
//    }
//
////    import Cocoa
////
////    class TextViewState {
////
////        // MARK: Initialization
////
////        private var textView: TextView
////        var paragraph: Paragraph
////
////        init(_ textView: TextView) {
////            self.textView = textView
////
////            self.paragraph = Paragraph()
////            self.paragraph.parent = self
////        }
////
////        // MARK: Simple getters
////
////        var storage: NSTextStorage {
////            textView.textStorage!
////        }
////
////        var selectedRange: NSRange {
////            textView.selectedRange()
////        }
////
////        /// NSTextStorage content as a string
////        var string: String {
////            storage.string
////        }
////
////        /// NSTextStorage content as a mutable string
////        var mutableString: NSMutableString {
////            return storage.mutableString
////        }
////
////        /// Return the line number of the line where the cursor currently is
////        var currentLine: Int {
////            paragraph.current().getLineNumber()
////        }
////
////        /// The span of lines selected when multiple lines have been selected
////        var multilineSelectedRange: (Int, Int)? = nil
////
////        /// Get the NSRange of the entire NSTextStorage content
////        var fullRange: NSRange {
////            return NSMakeRange(0, string.count)
////        }
////    }
////
////    extension TextViewState {
////        class Paragraph {
////            // MARK: Class Initialization
////
////            unowned var parent: TextViewState!
////            private var selection: Selection = Selection()
////
////            private enum Selection {
////                init() {
////                    self = .lineNumber(0)
////                }
////
////                case range(NSRange)
////                case lineNumber(Int)
////            }
////
////            // MARK: From (range, line number, current cursor position)
////            func from(range: NSRange) -> Paragraph {
////                selection = .range(range)
////
////                return self
////            }
////
////            func from(lineNumber: Int) -> Paragraph {
////                selection = .lineNumber(lineNumber)
////
////                return self
////            }
////
////            func current() -> Paragraph {
////                selection = .range(parent.selectedRange)
////
////                return self
////            }
////
////            // MARK: Get the following thing...
////
////            /// Return the range of the range provided as a parameter, if not nil, otherwise return the range of the paragraph where the cursor is currently
////            /// - Parameter range: some optional range
////            /// - Returns:range of a paragraph
////            func getRange() -> NSRange {
////                switch selection {
////                    case .range(let r):
////                        return parent.mutableString.paragraphRange(for: r)
////                    case .lineNumber(let l):
////                        let chars: [Character] = Array(parent.string)
////                        var indices: [Int] = [0]
////
////                        for (idx, char) in chars.enumerated()
////                        {
////                            if char == "\n" || char == "\r"
////                            {
////                                indices.append(idx + 1)
////                            }
////                        }
////
////                        indices.append(chars.count)
////
////                        if let from = indices[safe: l], let to = indices[safe: l + 1], from <= to
////                        {
////                            if from == to
////                            {
////                                return NSRange(location: parent.string.count, length: 0)
////                            }
////
////                            return NSRange(location: from, length: to - from)
////                        }
////                        else
////                        {
////                            return NSRange(fakeNull: true)
////                        }
////                }
////            }
////
////            /// Return the attributed substring of the paragraph where the range is (provided range as parameter if not nil, otherwise the current selected
////            /// range)
////            /// - Parameter range: some optional range
////            /// - Returns: Attributed substring of a paragraph
////            /// # Question #
////            ///  What if the current selection is multiple paragraphs? What happens then.
////            func getAttributedSubstring() -> NSAttributedString {
////                let paragraphRange = getRange()
////
////                return parent.storage.attributedSubstring(from: paragraphRange)
////            }
////
////            /// Return the string of the paragraph where the range is (provided range as parameter if not nil, otherwise the current selected range)
////            /// - Parameter range: some optional range
////            /// - Returns: Attributed substring of a paragraph
////            func getString() -> String {
////                return getAttributedSubstring().string
////            }
////
////            func getLineNumber() -> Int {
////                switch selection {
////                    case .range(let r):
////                        let str = parent.storage.attributedSubstring(from: NSMakeRange(0, r.location)).string
////                        let count = str.countInstances(of: "\n") + str.countInstances(of: "\r")
////
////                        return count
////                    case .lineNumber(let l):
////                        return l
////                }
////            }
////
////            func setString(str: String) {
////                parent.storage.replaceCharacters(in: getRange(), with: NSAttributedString(string: str))
////            }
////        }
////    }
//
//
//
//
////    func test_SidebarNode_initializer() throws {
////        XCTAssertNotNil(node.linkTo, "SidebarNode doesn't set a default 'linkTo' when none is specified (it should)")
////        XCTAssertNotNil(node.icon, "SidebarNode doesn't set a default 'icon' when none is specified (it should)")
////        XCTAssertNotNil(node.children, "SidebarNode doesn't set a default 'children' when none is specified (it should)")
////
////        XCTAssertEqual(node.children.count, 0, "SidebarNode doesn't set 'children' as an empty array by default.")
////    }
////
////    func test_SidebarNode_getters() {
////        XCTAssertTrue(node.isLeaf, "Default empty node is not a leaf")
////        XCTAssertEqual(node.count, 0, "'count' getter doesn't return 0 (children) on a default empty node")
////
////        node.children.append(SidebarNode(name: "Child 1"))
////        node.children.append(SidebarNode(name: "Child 2"))
////        node.children.append(SidebarNode(name: "Child 3"))
////
////        XCTAssertEqual(node.count, 3, "'count' getter doesn't return 3 (children) after appending 3 children.")
////        XCTAssertFalse(node.isLeaf, "Node 'isLeaf' despite having children.")
////    }
////
////    func test_SidebarNode_icon() throws {
////        XCTAssertNotNil(node.iconAsImage, "Default initialization icon doesn't load as an actual NSImage")
////
////        node.icon = "book"
////
////        print(node.icon)
////        print(node.iconAsImage?.isValid)
////
////        XCTAssertTrue(node.iconAsImage!.isValid, "iconAsImage returns a valid NSImage when 'icon' is set to a valid default icon name")
////    }
//}
