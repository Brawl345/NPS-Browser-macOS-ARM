//
//  DownloadListItemCellView.swift
//  NPS Browser
//
//  Created by JK3Y on 5/19/18.
//  Copyright © 2018 JK3Y. All rights reserved.
//

import Cocoa
import SwiftyUserDefaults

class DownloadListItemCellView: NSTableCellView {

    @IBOutlet weak var btnAction: NSButton!
    var item: DLItem?

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        item = objectValue as? DLItem
        guard item != nil else { return }
        changeImage()
    }
    
    @IBAction func doAction(_ sender: Any) {
        if (item?.isResumable)! {
            resumeRequest()
        } else if (item?.isStoppable)! {
            stopRequest()
        } else if (item?.isViewable)! {
            viewFile()
        }
    }
    
    func changeImage() {
        guard let item = item else { return }
        if item.isResumable {
            btnAction.image = #imageLiteral(resourceName: "Start")
        } else if item.isStoppable {
            btnAction.image = #imageLiteral(resourceName: "Stop")
        } else if item.isViewable {
            btnAction.image = #imageLiteral(resourceName: "Reveal")
        }
    }
    
    func stopRequest() {
        item!.request?.cancel()
        item!.status = DLStatus.stopped
        item!.makeResumable()
    }
    
    func viewFile() {
        guard let item = item,
              let consoleType = item.consoleType,
              let dlFolder = Defaults[.dl_library_folder]?.asFileURL else { return }

        var location = dlFolder.appendingPathComponent(consoleType, isDirectory: true)

        if Defaults[.xt_extract_after_downloading],
           let ct = ConsoleType(rawValue: consoleType),
           let ft = FileType(rawValue: item.fileType!),
           let xtFolder = Defaults[.xt_library_folder]?.asFileURL {
            location = xtFolder.appendingPathComponent(consoleType, isDirectory: true)

            switch (ct) {
            case .PSV:
                switch (ft) {
                case .Game:
                    location.appendPathComponent("app/\(item.titleId!)")
                case .DLC:
                    location.appendPathComponent("addcont/\(item.titleId!)")
                case .Update:
                    location.appendPathComponent("patch/\(item.titleId!)")
                case .Theme:
                    location.appendPathComponent("bgdl/t")
                default: break
                }
            case .PSP:
                location.appendPathComponent("pspemu/ISO")
            case .PSX:
                location.appendPathComponent("pspemu")
            case .PS3:
                location = dlFolder.appendingPathComponent(consoleType, isDirectory: true)
            case .All: break
            }
        }

        if !FileManager.default.fileExists(atPath: location.path) {
            log.warning("Reveal target \(location.path) does not exist, falling back to library folder")
            location = dlFolder
        }

        NSWorkspace.shared.open(location)
    }
    
    func resumeRequest() {
        item!.status = "Resuming..."
        Helpers().getSharedAppDelegate().downloadManager.resumeDownload(data: item!)
        
        item?.makeStoppable()
    }
}
