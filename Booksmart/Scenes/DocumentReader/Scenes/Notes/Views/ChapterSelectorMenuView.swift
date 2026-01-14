import SwiftUI

/// The view with the current chapter and a popover for selecting chapter when you click on it
struct ChapterSelectorMenuView: View {
    let chapters: [OutlineItem]
    @Binding var current: OutlineItem
    
    @State private var showPopover = false
    
    var body: some View {
        Button(action: {
            showPopover.toggle()
        }, label: {
            outlineItemInformativeLabel(current, withPadding: false)
                .padding(7)
                .border(Color.Monochrome.LightGray, width: 2)
                .cornerRadius(5)
                .lineLimit(1)
        })
        .buttonStyle(.plain)
        .frame(maxWidth: 350)
        .popover(isPresented: $showPopover) {
            ScrollView {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(chapters) { item in
                        Button(action: {
                            current = item
                            showPopover = false
                        }, label: {
                            outlineItemInformativeLabel(item, withPadding: true)
                        })
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .frame(maxWidth: 500, maxHeight: 700, alignment: .topLeading)
        }
    }
    
    @ViewBuilder
    private func outlineItemInformativeLabel(_ item: OutlineItem, withPadding: Bool) -> some View {
        HStack(alignment: .center, spacing: 6) {
            Text(item.chapter.getPrefix())
                .frame(width: 30, height: 20)
                .background(Color.Primary.Light)
                .cornerRadius(5)
                .foregroundColor(.white)
                .font(.body)

            Text(item.label)
                .foregroundColor(.black)
        }
        .padding(.leading, withPadding ? 20 * CGFloat(item.chapter.depth() - 1) : 0)
    }
}
