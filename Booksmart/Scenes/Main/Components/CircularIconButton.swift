import SwiftUI

struct CircularIconButton: View {
    let icon: Image
    let iconSize: CGFloat
    let size: CGFloat
    var action: () -> Void
    
    init(icon: String, iconSize: CGFloat, size: CGFloat, action: @escaping () -> Void) {
        self.icon = Image(systemName: icon)
        self.iconSize = iconSize
        self.size = size
        self.action = action
    }
    
    init(icon: Image, iconSize: CGFloat, size: CGFloat, action: @escaping () -> Void) {
        self.icon = icon
        self.iconSize = iconSize
        self.size = size
        self.action = action
    }

    
    var body: some View {
        Button(action: action, label: {
            ZStack(alignment: .center) {
                Circle()
                    .fill(Color.Monochrome.LightGray)
                    .frame(width: size, height: size, alignment: .center)
                
                icon
                    .resizable()
                    .scaledToFit()
                    .frame(width: iconSize, height: iconSize, alignment: .center)
            }
        })
        .buttonStyle(PlainButtonStyle())
    }
}

struct CircularIconButton_Previews: PreviewProvider {
    static var previews: some View {
        CircularIconButton(icon: Image(systemName: "chevron.right"), iconSize: 10, size: 20, action: {})
    }
}

