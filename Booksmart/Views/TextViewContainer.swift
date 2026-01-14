import Combine
import SwiftUI

/// SwiftUI view containing NSViewRepresentable with the text view
struct TextViewContainer: NSViewRepresentable {
	@Binding var text: String
	
	var onEditingChanged: () -> Void       = {}
	var onCommit        : () -> Void       = {}
	var onTextChange    : (String) -> Void = { _ in }
	
	func makeNSView(context: Context) -> CustomTextView {
		let textView = CustomTextView(text: "")
		return textView
	}
	
	func updateNSView(_ view: CustomTextView, context: Context) {
		view.text = text
	}
}

// MARK: - CustomTextView

final class CustomTextView: NSView {
	weak var delegate: NSTextViewDelegate?
	
	var text: String
	
	private lazy var scrollView: NSScrollView = {
		let scrollView = NSScrollView()
			scrollView.drawsBackground = true
			scrollView.borderType = .noBorder
			scrollView.hasVerticalScroller = true
			scrollView.hasHorizontalRuler = false
			scrollView.autoresizingMask = [.width, .height]
			scrollView.translatesAutoresizingMaskIntoConstraints = false
			
		return scrollView
	}()
	
	private lazy var textView: NSTextView = {
		let contentSize = scrollView.contentSize
		
        let textView                     = TextView(frame: NSRect(origin: NSPoint(), size: contentSize))
		textView.autoresizingMask        = .width
		textView.backgroundColor         = NSColor.textBackgroundColor
		textView.drawsBackground         = true
		textView.textContainerInset		 = NSMakeSize(60.0, 30.0)
		textView.isEditable              = true
		textView.isHorizontallyResizable = false
		textView.isVerticallyResizable   = true
		textView.maxSize                 = NSSize(width: CGFloat.greatestFiniteMagnitude,
												  height: CGFloat.greatestFiniteMagnitude)
		textView.minSize                 = NSSize(width: 0, height: contentSize.height)
		textView.allowsUndo              = true
		textView.insertionPointColor     = NSColor.Primary.Primary
		
		return textView
	}()
	
	// MARK: - Init
	
	init(text: String) {
		self.text = text
		super.init(frame: .zero)
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	// MARK: - Life cycle
	
	override func viewWillDraw() {
		super.viewWillDraw()
		
		setupScrollViewConstraints()
		setupTextView()
	}
	
	func setupScrollViewConstraints() {
		scrollView.translatesAutoresizingMaskIntoConstraints = false
		
		addSubview(scrollView)
		
		NSLayoutConstraint.activate([
			scrollView.topAnchor.constraint(equalTo: topAnchor),
			scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
			scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
			scrollView.leadingAnchor.constraint(equalTo: leadingAnchor)
		])
	}
	
	func setupTextView() {
		scrollView.documentView = textView
	}
	
}
