import SwiftUI

struct FlashcardsView: View {
    @EnvironmentObject var readerState: ReaderState
    
    var flashcardsState: FlashcardsState {
        readerState.flashcardsState
    }
    
    var body: some View {
        VStack(alignment: .center) {
            picker
            
            VStack {
                switch flashcardsState.selectedTab
                {
                case .create:
                    CreateFlashcardView(parent: flashcardsState)
                case .browse:
                    BrowseFlashcardsView(parent: flashcardsState)
                case .study:
                    StudyFlashcardsView(parent: flashcardsState)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.slide)
        }
        .animation(.linear, value: flashcardsState.selectedTab)
        .background(Color.white)
        .padding()
    }
    
    var picker: some View {
        HStack {
            Picker("", selection: $readerState.flashcardsState.selectedTab) {
                ForEach(flashcardsState.tabs, id: \.self) { tab in
                    Text(tab.rawValue)
                }
            }
            .font(.system(size: 12))
            .pickerStyle(.segmented)
        }
        .fixedSize()
        .padding(.vertical, 26)
    }
}

struct FlashcardsView_Previews: PreviewProvider {
    static var previews: some View {
		FlashcardsView()
    }
}
