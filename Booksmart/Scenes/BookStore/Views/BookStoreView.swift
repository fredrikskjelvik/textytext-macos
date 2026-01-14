import SwiftUI

struct BookStoreView: View {
    @EnvironmentObject var router: Router
    @EnvironmentObject var vm: BookStoreVM
    
    var body: some View {
        VStack {
            if let book = vm.book {
                Text(book.title)
                Text(book.category)
            } else {
                Text("No book")
            }
        }
    }
}
