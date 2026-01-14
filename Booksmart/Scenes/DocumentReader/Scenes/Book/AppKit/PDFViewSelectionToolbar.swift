import Cocoa
import PDFKit

class PDFViewSelectionToolbar: NSViewController {
    var highlighter: PDFHighlighter!
    var selection: PDFSelectionManager? = nil

    init(highlighter: PDFHighlighter) {
        super.init(nibName: nil, bundle: nil)
        self.highlighter = highlighter
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
    }
    
    @IBAction func onClickYellowHighlight(_ sender: Any) {
        if let selection = selection {
            highlighter.highlight(selection: selection, color: .systemYellow)
        }
    }
    
    @IBAction func onClickBlueHighlight(_ sender: Any) {
        if let selection = selection {
            highlighter.highlight(selection: selection, color: .systemBlue)
        }
    }
    
    @IBAction func onClickRedHighlight(_ sender: Any) {
        if let selection = selection {
            highlighter.highlight(selection: selection, color: .systemRed)
        }
    }
    
    @IBAction func onClickGreenHighlight(_ sender: Any) {
        if let selection = selection {
            highlighter.highlight(selection: selection, color: .systemGreen)
        }
    }
    
}

