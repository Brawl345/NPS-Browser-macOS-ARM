//
//  Helpers.swift
//  NPS Browser
//
//  Created by JK3Y on 6/3/18.
//  Copyright © 2018 JK3Y. All rights reserved.
//

import Cocoa
import Foundation
import SwiftyUserDefaults

extension URL {
    // Legacy defaults may contain archived NSURLs without a file:// scheme
    var asFileURL: URL {
        isFileURL ? self : URL(fileURLWithPath: path)
    }
}

class Helpers {

    static func storeFolderBookmark(url: URL, key: DefaultsKey<Data?>) {
        do {
            Defaults[key] = try url.bookmarkData(options: .withSecurityScope,
                                                 includingResourceValuesForKeys: nil,
                                                 relativeTo: nil)
        } catch {
            log.error("Could not create bookmark for \(url.path): \(error)")
        }
    }

    static func restoreFolderAccess(key: DefaultsKey<Data?>) {
        guard let data = Defaults[key] else { return }
        do {
            var isStale = false
            let url = try URL(resolvingBookmarkData: data,
                              options: .withSecurityScope,
                              relativeTo: nil,
                              bookmarkDataIsStale: &isStale)
            guard url.startAccessingSecurityScopedResource() else {
                log.error("Could not access security-scoped folder \(url.path)")
                return
            }
            if isStale {
                storeFolderBookmark(url: url, key: key)
            }
        } catch {
            log.error("Could not resolve folder bookmark: \(error)")
        }
    }

    func makeAlert(messageText: String = "", informativeText: String = "", alertStyle: NSAlert.Style = .warning) {
        let alert = NSAlert()
        alert.messageText = messageText
        alert.informativeText = informativeText
        alert.alertStyle = alertStyle
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    func makeNotification(title: String, subtitle: String) {
        getSharedAppDelegate().showNotification(title: title, subtitle: subtitle)
    }
    
    func getSharedAppDelegate() -> AppDelegate {
        return NSApp.delegate as! AppDelegate
    }
    
    func getWindowDelegate() -> WindowDelegate {
        return NSApp.windows.first?.windowController as! WindowController
    }
    
    func getDataController() -> DataViewController {
        return getWindowDelegate().getDataController()
    }
        
    func getLoadingViewController() -> LoadingViewController {
        return getWindowDelegate().getLoadingViewController()
    }
    
    func showLoadingViewController() {
        getDataController().presentAsSheet(getWindowDelegate().getLoadingViewController())
    }
    
    func getRowObjectFromTableRowButton(_ sender: NSButton) -> Any? {
        var superView = sender.superview
        while let view = superView, !(view is NSTableCellView) {
            superView = view.superview
        }
        guard let cell = superView as? NSTableCellView else {
            print("Sender is not in a table view cell!")
            return nil
        }
        
        return cell.objectValue
    }
    
    func makeDLItem(data: Item, downloadUrl: URL, fileType: FileType) -> DLItem {
        let obj = DLItem()

        obj.titleId        = data.titleId
        obj.name            = "\(fileType.rawValue) - \(data.name!)"
        obj.downloadUrl   = downloadUrl
        obj.zrif = data.zrif
        if fileType == .Game {
            obj.sha256 = data.sha256
        }
        obj.consoleType = data.consoleType
        obj.fileType = fileType.rawValue

        return obj
    }
    
    func relativePast(for date : Date?) -> String {
        if (date == nil) {
            return "Never"
        }
        
        let units = Set<Calendar.Component>([.year, .month, .day, .hour, .minute, .second, .weekOfYear])
        let components = Calendar.current.dateComponents(units, from: date!, to: Date())
        
        if components.year! > 0 {
            return "\(components.year!) " + (components.year! > 1 ? "years ago" : "year ago")

        } else if components.month! > 0 {
            return "\(components.month!) " + (components.month! > 1 ? "months ago" : "month ago")
            
        } else if components.weekOfYear! > 0 {
            return "\(components.weekOfYear!) " + (components.weekOfYear! > 1 ? "weeks ago" : "week ago")
            
        } else if (components.day! > 0) {
            return (components.day! > 1 ? "\(components.day!) days ago" : "Yesterday")
            
        } else if components.hour! > 0 {
            return "\(components.hour!) " + (components.hour! > 1 ? "hours ago" : "hour ago")
            
        } else if components.minute! > 0 {
            return "\(components.minute!) " + (components.minute! > 1 ? "minutes ago" : "minute ago")
        } else {
            return components.second! > 5 ? "\(components.second!) seconds ago" : "Just Now"
        }
    }
    
    func getUrlSettingsByType(itemType: ItemType) -> URL? {
        switch (itemType.console) {
        case .PSV:
            switch (itemType.fileType) {
            case .Game: return Defaults[.src_psv_games]
            case .DLC: return Defaults[.src_psv_dlcs]
            case .Theme: return Defaults[.src_psv_themes]
            case .CPack: return Defaults[.src_compatPacks]
            case .CPatch: return Defaults[.src_compatPatch]
            default: break
            }
        case .PS3:
            switch (itemType.fileType) {
            case .Game: return Defaults[.src_ps3_games]
            case .DLC: return Defaults[.src_ps3_dlcs]
            case .Theme: return Defaults[.src_ps3_themes]
            case .Avatar: return Defaults[.src_ps3_avatars]
            default: break
            }
        case .PSP: return Defaults[.src_psp_games]
        case .PSX: return Defaults[.src_psx_games]
        }
        
        return nil
    }
}
