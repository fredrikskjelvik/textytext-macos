import Cocoa
import PDFKit

class PDFViewController: NSViewController, PDFViewDelegate {
    var pdfView: CustomPDFView
    
    init(coordinator: PDFViewContainerDelegate) {
        self.pdfView = CustomPDFView(frame: NSRect(x: 100, y: 100, width: 100, height: 100), coordinator: coordinator)
        
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
        
        self.view.addSubview(pdfView)
        
        pdfView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            pdfView.topAnchor.constraint(equalTo: view.topAnchor),
            pdfView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            pdfView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            pdfView.leadingAnchor.constraint(equalTo: view.leadingAnchor)
        ])
    }
    
    override func viewDidLayout() {
        pdfView.initialize()
    }

    func setupPDF(document: PDFDocument) {
        pdfView.document = document
        pdfView.autoScales = true
        pdfView.backgroundColor = NSColor.white
        pdfView.minScaleFactor = 1
        pdfView.maxScaleFactor = 5
        pdfView.displayMode = .singlePageContinuous
        pdfView.displaysPageBreaks = false
        pdfView.pageShadowsEnabled = true
    }
}

