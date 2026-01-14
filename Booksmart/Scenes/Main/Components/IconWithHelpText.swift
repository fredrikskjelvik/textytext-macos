import SwiftUI

struct IconWithHelpText: View {
    let icon: String
    let text: String
    
    var body: some View {
        Image(systemName: icon)
            .help(Text(text))
    }
}
