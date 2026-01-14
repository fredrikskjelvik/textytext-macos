import Cocoa
import PDFKit

final class TextViewController: NSViewController {
    let coordinator: TextViewContainerDelegate
    let textContainerInset: NSSize
    let isEditable: Bool
    let isScrollable: Bool
    
    init(coordinator: TextViewContainerDelegate, textContainerInset: NSSize, isEditable: Bool = true, isScrollable: Bool = true) {
        self.coordinator = coordinator
        self.textContainerInset = textContainerInset
        self.isEditable = isEditable
        self.isScrollable = isScrollable
        
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        self.view = NSView()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.addSubview(scrollView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor)
        ])
        
        scrollView.documentView = textView
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        
        coordinator.viewDidAppearWithProperties(height: textView.frame.height)
    }
    
    private lazy var scrollView: NSScrollView = {
        let scrollView = NSScrollView()
            scrollView.drawsBackground = true
            scrollView.borderType = .noBorder
            scrollView.hasVerticalScroller = isScrollable
            scrollView.hasHorizontalRuler = false
            scrollView.autoresizingMask = [.width, .height]
            scrollView.translatesAutoresizingMaskIntoConstraints = false
            
        return scrollView
    }()
    
    public lazy var textView: TextView = {
        return makeTextView()
    }()
    
    private func makeTextView() -> TextView {
        let contentSize = scrollView.contentSize
        
        let textView = TextView(frame: NSRect(origin: NSPoint(), size: contentSize), inset: textContainerInset)
            textView.autoresizingMask = .width
            textView.backgroundColor = NSColor.textBackgroundColor
            textView.drawsBackground = true
            textView.isHorizontallyResizable = false
            textView.isVerticallyResizable = true
            textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude,
                                      height: CGFloat.greatestFiniteMagnitude)
            textView.minSize = NSSize(width: 0, height: contentSize.height)
            textView.allowsUndo = true
            textView.containerDelegate = coordinator
            textView.initialize()
            textView.isEditable = isEditable
            textView.isScrollable = isScrollable
        
        return textView
    }
    
    func reloadView() {
        textView = makeTextView()
        
        if view.subviews.count == 1,
           let scrollView = view.subviews[0] as? NSScrollView
        {
            scrollView.documentView = textView
        }
        else
        {
            fatalError("4893248324")
        }
    }
}
