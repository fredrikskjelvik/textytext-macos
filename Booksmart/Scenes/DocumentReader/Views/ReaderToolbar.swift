import SwiftUI

struct ReaderToolbar: ViewModifier {
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject var router: Router
    @EnvironmentObject var readerState: ReaderState
    
    @State private var isSubsceneHoppingPopoverPresented = false
    
    func body(content: Content) -> some View {
        content
            .navigationTitle("Reader")
            .toolbar(content: {
                ToolbarItem(placement: .navigation) {
                    Menu(
                        content: {
                            Group {
                                Button("Home") {
                                    openWindow(id: "dashboard")
                                    NSApplication.shared.keyWindow?.close()
                                }
                            }
                        },
                        label: {
                            Text(readerState.document.name)
                                .font(.title2)
                                .fontWeight(.semibold)
                                .padding()
                        }
                    )
                    .menuStyle(BorderlessButtonMenuStyle())
                }
                
                ToolbarItem(placement: .principal) {
                    HStack {
                        Button(action: {
                            readerState.subsceneLayout.toggle(.book)
                        }, label: {
                            Text("Book").help("⌘+1")
                        })
                        .keyboardShortcut("1", modifiers: [.command])
                        
                        Button(action: {
                            readerState.subsceneLayout.toggle(.notes)
                        }, label: {
                            Text("Notes").help("⌘+2")
                        })
                        .keyboardShortcut("2", modifiers: [.command])
                        
                        Button(action: {
                            readerState.subsceneLayout.toggle(.flashcards)
                        }, label: {
                            Text("Flashcards").help("⌘+3")
                        })
                        .keyboardShortcut("3", modifiers: [.command])
                    }
                }
                
                ToolbarItem(placement: .status) {
                    Spacer()
                }
                
                ToolbarItem(placement: .status) {
                    Button(action: {
                        NSApp.keyWindow?.firstResponder?.tryToPerform(#selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
                    }) {
                        Image(systemName: "magnifyingglass")
                    }
                    .keyboardShortcut("p", modifiers: [.command])
                }
                
                ToolbarItem(placement: .status) {
                    Button(action: {
                        isSubsceneHoppingPopoverPresented.toggle()
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .popover(isPresented: $isSubsceneHoppingPopoverPresented) {
                        List {
                            Button("Go to book chapter in notes") {
                                let bookChapter = readerState.bookState.currentOutlineItem.chapter
                                
                                if let notesChapter = readerState.outlineContainer.getOutlineItem(.chapter(bookChapter), depthLimited: true) {
                                    readerState.notesState.currentOutlineItem = notesChapter
                                }
                            }
                            
                            Button("Go to notes chapter in book") {
                                let notesChapter = readerState.notesState.currentOutlineItem
                                
                                readerState.bookState.setOutlineItem(notesChapter)
                            }
                        }
                    }
                }
                
                ToolbarItem(placement: .status) {
                    Button(action: {}) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
                
                ToolbarItem(placement: .status) {
                    Button(action: {
                        readerState.subsceneLayout.switchOrientation()
                    }) {
                        Image(systemName: "rotate.left")
                    }
                }

                ToolbarItem(placement: .status) {
                    Button(
                        action: {
                            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
                        },
                        label: {
                            Image(systemName: "gearshape")
                        }
                    )
                }
            })
        }
}

extension View {
    func readerToolbar() -> some View {
        modifier(ReaderToolbar())
    }
}
