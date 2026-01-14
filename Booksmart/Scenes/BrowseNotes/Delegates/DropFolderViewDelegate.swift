//
//  DropFolderViewDelegate.swift
//  Booksmart
//
//  Created by Felix Marianayagam on 19/12/22.
//

import SwiftUI

struct DropFolderViewDelegate: DropDelegate {
    var model: BrowseFoldersAndDocumentsViewModel? = nil
    let folder: FolderDB
    // Updated when coming from breadcrumb.
    var router: Router? = nil

    var notFromBreadcrumb: Bool {
        router == nil
    }

    func dropEntered(info: DropInfo) {
        if notFromBreadcrumb {
            model?.dropEntered(folder: folder)
        }
        else {
            router?.dropEntered(folder: folder)
        }
    }

    func dropExited(info: DropInfo) {
        if notFromBreadcrumb {
            model?.dropExited()
        }
        else {
            router?.dropExited()
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }
    
    func performDrop(info: DropInfo) -> Bool {
        if notFromBreadcrumb {
            return model?.performDrop() ?? false
        }
        else {
            return router?.performDrop() ?? false
        }
    }
}
