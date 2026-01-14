import SwiftUI

struct PlainButtonComponent: View {
    let text: String
    let background: Color
    let textColor: Color
    let action: () -> Void
    
    init(
        text: String,
        background: Color = Color.Secondary.Regular,
        textColor: Color = Color.Monochrome.Gray,
        action: @escaping ()-> Void
    ){
        self.text = text
        self.background = background
        self.textColor = textColor
        self.action = action
    }
    var body: some View {
        Button {
            action()
        } label: {
            Text(text)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(background)
                .cornerRadius(8)
                .foregroundColor(textColor)
                .font(.system(size: 13))
        }
        .buttonStyle(.plain)
        .background(Color.white.cornerRadius(8))
    }
}

struct PlainButtonComponet_Previews: PreviewProvider {
    static var previews: some View {
        PlainButtonComponent(text: "Add tags", action: {})
    }
}
