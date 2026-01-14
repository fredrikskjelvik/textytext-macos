import SwiftUI

struct BlurEffect: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Rectangle().fill(Color.white).blur(radius: 50, opaque: false))
    }
}

extension View {
    func blurEffect() -> some View {
        self.modifier(BlurEffect())
    }
}
