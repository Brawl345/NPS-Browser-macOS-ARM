//
//  DetailsViewController.swift
//  NPS Browser
//
//  Created by JK3Y on 5/6/18.
//  Copyright © 2018 JK3Y. All rights reserved.
//

import Cocoa

class DetailsViewController: NSViewController {

    @IBOutlet weak var chkBookmark: NSButton!
    @IBOutlet weak var btnDownload: NSButton!
    @IBOutlet weak var chkDLGame: NSButton!
    @IBOutlet weak var chkDLUpdate: NSButton!
    @IBOutlet weak var chkDLCompatPack: NSButton!

    var windowDelegate: WindowDelegate?
    private var pendingUpdateCheck: DispatchWorkItem?

    override var representedObject: Any? {
        didSet {
            enableBookmarkButton()
            toggleBookmark()
            enableDownloadOptions()
            
            getBoxartViewController().representedObject = representedObject
        }
    }

    @IBAction func btnDownloadClicked(_ sender: Any) {
        let obj = getROManagedObject()

        var baseDLItem: DLItem? = nil

        if (chkDLGame.state == .on && obj.hasDownloadLink) {
            if let url = try? obj.pkgDirectLink!.asURL() {
                self.sendDLData(url: url, fileType: .Game)
            }
        }
        if (chkDLUpdate.state == .on && chkDLUpdate.isEnabled && chkDLUpdate.isHidden == false) {
            if let url = GameUpdateService.shared.cachedUpdateURL(titleId: obj.titleId!) {
                sendDLData(url: url, fileType: .Update)
            }
        }
        if (chkDLCompatPack.state == .on && chkDLCompatPack.isEnabled && chkDLCompatPack.isHidden == false) {
            let ct: ConsoleType = ConsoleType(rawValue: obj.consoleType!)!
            let ft: FileType = FileType(rawValue: obj.fileType!)!
            switch(ct) {
            case .PS3:
                Helpers().getSharedAppDelegate().downloadManager.generateRapFile(data: obj)
            case .PSV:
                switch(ft) {
                case .Game:
                    let titleId = obj.titleId
                    
                    if let cpacko: CompatPack = DBManager().fetch(CompatPack.self, predicate: NSPredicate(format: "titleId == %@ AND type == 'CompatPack'", titleId!), sorted: nil).first {
                        let url = URL(string: (cpacko.downloadUrl)!)
                        baseDLItem = Helpers().makeDLItem(data: obj, downloadUrl: url!, fileType: .CPack)
                    }
                    
                    if let cpatcho: CompatPack = DBManager().fetch(CompatPack.self, predicate: NSPredicate(format: "titleId == %@ AND type == 'CompatPatch'", titleId!), sorted: nil).first {
                        let url = URL(string: (cpatcho.downloadUrl)!)
                        let item = Helpers().makeDLItem(data: obj, downloadUrl: url!, fileType: .CPatch)
                        if baseDLItem == nil {
                            baseDLItem = item
                        } else {
                            baseDLItem?.doNext = item
                            item.parentItem = baseDLItem
                        }
                    }
                    
                    if let dlItem = baseDLItem {
                        Helpers().getSharedAppDelegate().downloadManager.addToDownloadQueue(data: dlItem)
                    }
                default: break
                }
            default: break
            }
        }
    }
    
    @IBAction func btnBookmarkToggle(_ sender: NSButton) {
        if (sender.state == .on) {
            let bookmark = Bookmark(item: getROManagedObject())
            DBManager().store(object: bookmark)
        } else {
            let bookmark = DBManager().fetch(Bookmark.self, predicate: NSPredicate(format: "uuid == %@", getROManagedObject().pk)).first
            DBManager().delete(object: bookmark!)
        }
    }

    func enableBookmarkButton() {
        let obj = getROManagedObject()
        let hasLink = obj.hasDownloadLink
        btnDownload.isEnabled = hasLink
        chkBookmark.isEnabled = hasLink
        btnDownload.toolTip = hasLink ? nil : (obj.pkgDirectLink?.capitalized ?? "No download available")
    }
    
    func enableDownloadOptions() {
        let ctype: ConsoleType = ConsoleType(rawValue: getROManagedObject().consoleType!)!
        let ftype: FileType = FileType(rawValue: getROManagedObject().fileType!)!
        
        chkDLGame.title = ftype.rawValue
        
        switch(ctype) {
        case .PSV:
            switch(ftype) {
            case .Game:
                let titleId = getROManagedObject().titleId
                chkDLCompatPack.title = "CPack"
                chkDLGame.isEnabled = true
                configureUpdateCheckbox(titleId: titleId!)
                chkDLCompatPack.isHidden = false
                
                try! RealmStorageContext().fetch(CompatPack.self, predicate: NSPredicate(format: "titleId == %@", titleId!)) { result in
                    if (result.isEmpty) {
                        chkDLCompatPack.isEnabled = false
                    } else {
                        chkDLCompatPack.isEnabled = true
                    }
                }
            default:
                chkDLCompatPack.isHidden = true
                chkDLCompatPack.isEnabled = false
                chkDLUpdate.isHidden = true
                chkDLUpdate.isEnabled = false
            }
        case .PS3:
            let rap = getROManagedObject().rap!
            chkDLCompatPack.isHidden = false
            chkDLUpdate.isHidden = true
            if (rap == "NOT REQUIRED" || rap == "UNLOCK/LICENSE BY DLC" || rap == "MISSING") {
                chkDLCompatPack.title = rap
                chkDLCompatPack.isEnabled = false
            } else {
                chkDLCompatPack.title = "RAP"
                chkDLCompatPack.isEnabled = true
            }
        default:
            chkDLUpdate.isHidden = true
            chkDLCompatPack.isHidden = true
        }
    }
    
    private func configureUpdateCheckbox(titleId: String) {
        pendingUpdateCheck?.cancel()
        chkDLUpdate.isHidden = false
        chkDLUpdate.isEnabled = false

        if let cached = GameUpdateService.shared.cachedAvailability(titleId: titleId) {
            applyUpdateAvailability(cached)
            return
        }
        chkDLUpdate.toolTip = "Checking for update…"

        // Debounced so arrow-key scrolling through the list doesn't fire
        // a request against Sony's update server for every row passed
        let work = DispatchWorkItem { [weak self] in
            GameUpdateService.shared.checkAvailability(titleId: titleId) { availability in
                guard let self = self,
                      (self.representedObject as? Item)?.titleId == titleId else { return }
                self.applyUpdateAvailability(availability)
            }
        }
        pendingUpdateCheck = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
    }

    private func applyUpdateAvailability(_ availability: GameUpdateService.Availability?) {
        switch availability {
        case .available?:
            chkDLUpdate.isEnabled = true
            chkDLUpdate.toolTip = nil
        case .unavailable?:
            chkDLUpdate.toolTip = "No update available"
        case nil:
            chkDLUpdate.toolTip = "Update check failed"
        }
    }

    func toggleBookmark() {
        let predicate = NSPredicate(format: "uuid == %@", getROManagedObject().pk)
        let bookmark = DBManager().fetch(Bookmark.self, predicate: predicate)

        if bookmark.isEmpty {
            chkBookmark.state = .off
        } else {
            chkBookmark.state = .on
        }
    }
    
    func toggleBookmark(comparePK: String) {
        if getROManagedObject().pk == comparePK {
            chkBookmark.state = .off
        }
    }

    func sendDLData(url: URL, fileType: FileType) {
        let obj = getROManagedObject()
        let dlItem = Helpers().makeDLItem(data: obj, downloadUrl: url, fileType: fileType)
        Helpers().getSharedAppDelegate().downloadManager.addToDownloadQueue(data: dlItem)
    }
    
    func getROManagedObject() -> Item {
        return representedObject as! Item
    }
    
    func getBoxartViewController() -> GameArtworkViewController {
      let vc: GameArtworkViewController = parent?.children[1] as! GameArtworkViewController
        return vc
    }
}
