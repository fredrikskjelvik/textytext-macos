import SwiftUI

/// The container for the entire "Notes" subcomponent/subscene thing.
/// Contains the toolbar and the TextView.
struct NotesContainer: View {
    var body: some View {
        VStack {
            TextViewContainer()
        }
        .frame(maxWidth: .infinity)
    }
}
