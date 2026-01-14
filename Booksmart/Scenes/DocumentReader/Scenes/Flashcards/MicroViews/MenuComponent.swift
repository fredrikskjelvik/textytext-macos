import SwiftUI

struct MenuComponent: View {
    let selector: String?
    let placeHolder: String
    let list: () -> [String]
    var onSelect: (Int) -> Void
    
    var body: some View {
        Menu {
            let list = list()
            ForEach(Array(zip(list.indices, list)), id: \.0) { index, item in
                Button {
                    onSelect(index)
                } label: {
                    Text(item)
                }
            }
        } label: {
            if let selector = selector
            {
                Text(selector)
            }
            else
            {
                Text(placeHolder)
            }
        }
        .font(.system(size: 14))
    }
}

struct MenuComponent_Previews: PreviewProvider {
    static var previews: some View {
        MenuComponent(selector: "", placeHolder: "Add Menu", list: { [] }, onSelect: { _ in})
    }
}
