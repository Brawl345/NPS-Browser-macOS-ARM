//
//  WindowController.swift
//  NPS Browser
//
//  Created by JK3Y on 5/6/18.
//  Copyright © 2018 JK3Y. All rights reserved.
//

import Cocoa
import RealmSwift
import SwiftyUserDefaults

class WindowController: NSWindowController, NSToolbarDelegate, WindowDelegate {
    @IBOutlet weak var progressSpinner: NSProgressIndicator!
    @IBOutlet weak var toolbar: NSToolbar!
    @IBOutlet weak var tbType: NSPopUpButton!
    @IBOutlet weak var tbRegion: NSPopUpButton!
    @IBOutlet weak var tbSearchBar: NSSearchField!
    var delegate: ToolbarDelegate?
    var loadingViewController: LoadingViewController?
    private weak var downloadVC: DownloadViewController?

    override func windowDidLoad() {
        super.windowDidLoad()
        let vc = self.storyboard?.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("loadingVC")) as! LoadingViewController
        loadingViewController = vc
        self.delegate = getDataController()
        tbRegion.selectItem(withTag: Defaults[.last_region])

        NotificationCenter.default.addObserver(self, selector: #selector(onDownloadStarted), name: .downloadStarted, object: nil)
    }

    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        if let vc = segue.destinationController as? DownloadViewController {
            downloadVC = vc
        }
    }

    @objc private func onDownloadStarted() {
        guard downloadVC?.view.window == nil else { return }
        performSegue(withIdentifier: "showDownloadsPanel", sender: self)
    }
    
    @IBAction func onTypeChanged(_ sender: Any) {
        delegate?.filterType(itemType: getItemType(), region: getRegion())
    }
    
    @IBAction func onRegionChanged(_ sender: Any) {
        Defaults[.last_region] = tbRegion.selectedItem?.tag ?? 0
        delegate?.filterType(itemType: getItemType(), region: getRegion())
    }

    @IBAction func onFilterSearchBar(_ sender: NSSearchField) {
        let searchString = tbSearchBar.stringValue
        
        if (!searchString.isEmpty) {
            delegate?.filterString(itemType: getItemType(), region: getRegion(), searchString: searchString)
        } else {
            delegate?.filterType(itemType: getItemType(), region: getRegion())
        }
    }
    
    @IBAction func reloadDatabase(_ sender: NSMenuItem) {
        NetworkManager().makeRequest()
    }

    func getDataController() -> DataViewController {
        let splitViewController = self.window!.contentViewController! as! NSSplitViewController
        let vc: DataViewController = splitViewController.splitViewItems[0].viewController as! DataViewController
        return vc
    }
    
    func getLoadingViewController() -> LoadingViewController {
        return loadingViewController!
    }

    func getItemType() -> ItemType {
        return ItemType.parseString((tbType.selectedItem?.title)!, ItemType.getTypeFromTag(tbType.selectedItem?.tag ?? 0))
    }
    
    func getRegion() -> String {
        let tag = tbRegion.selectedItem?.tag
        switch (tag) {
        case 0:
            return "US"
        case 1:
            return "EU"
        case 2:
            return "JP"
        case 3:
            return "ASIA"
        default:
            return "US"
        }
    }

}

import Foundation
class SplitViewController: NSSplitViewController {
    
    override func toggleSidebar(_ sender: Any?) {
        let mi = sender as! NSMenuItem
        debugPrint(mi.title)

        for view in splitViewItems {
            if view.canCollapse {
                if view.isCollapsed {
                    view.isCollapsed = false
                    mi.title = "Hide Sidebar"
                } else  {
                    view.isCollapsed = true
                    mi.title = "Show Sidebar"
                }
            }
        }
    }

}
