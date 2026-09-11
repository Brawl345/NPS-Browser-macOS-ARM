//
//  DataViewController.swift
//  NPS Browser
//
//  Created by JK3Y on 4/28/18.
//  Copyright © 2018 JK3Y. All rights reserved.
//

import Cocoa
import RealmSwift
import SwiftyUserDefaults

class DataViewController: NSViewController, ToolbarDelegate {
    
    @IBOutlet var tsvResultsController: NSArrayController!
    @IBOutlet weak var tableView: NSTableView!
    lazy var windowDelegate: WindowDelegate = Helpers().getWindowDelegate()

    var notificationToken: NotificationToken?
    private var didStartInitialRefresh = false

    private var realm: Realm = {
        return DBMigration.configureMigration()
    }()

    var items: Results<Item>? = try! Realm().objects(Item.self)

    override func viewDidAppear() {
        applyFilter()

        if !didStartInitialRefresh {
            didStartInitialRefresh = true
            NetworkManager().refreshAll()
        }
    }

    override var representedObject: Any? {
        didSet {
            self.getDetailsViewController().representedObject = representedObject
        }
    }

    @IBAction func tableSelectionChanged(_ sender: NSTableView) {
        if (!tsvResultsController.selectedObjects.isEmpty) {
            self.representedObject = tsvResultsController.selectedObjects.first
        }
    }
    
    func makePredicate(itemType: ItemType, region: String) -> NSPredicate {
        var clauses: [String] = []
        var args: [Any] = []

        if itemType.console != .All {
            clauses.append("consoleType == %@")
            args.append(itemType.console.rawValue)
        }
        if itemType.fileType != .All {
            clauses.append("fileType == %@")
            args.append(itemType.fileType.rawValue)
        }
        if region != ConsoleType.All.rawValue {
            clauses.append("region == %@")
            args.append(region)
        }

        if Defaults[.dsp_hide_invalid_url_items] {
            clauses.append("pkgDirectLink BEGINSWITH 'http'")
            clauses.append("(consoleType != 'PSV' OR zrif != 'MISSING')")
        }

        if clauses.isEmpty {
            return NSPredicate(value: true)
        }
        return NSPredicate(format: clauses.joined(separator: " AND "), argumentArray: args)
    }

    func applyFilter() {
        let itemType = windowDelegate.getItemType()
        let region = windowDelegate.getRegion()
        let searchString = windowDelegate.getSearchString()

        let matches = items!.filter(makePredicate(itemType: itemType, region: region))
        let objects = searchString.isEmpty ? matches : matches.filter("name contains[c] %@", searchString)

        showTypeColumn(itemType.console == .All || itemType.fileType == .All)
        setArrayControllerContent(content: objects)
    }

    private func showTypeColumn(_ visible: Bool) {
        let column = tableView.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier("TypeColumn"))
        column?.isHidden = !visible
    }

    func setArrayControllerContent(content: Results<Item>?) {
        let objects = content.map { Array($0) } ?? []
        tsvResultsController.content = objects

        if objects.isEmpty {
            representedObject = nil
        } else {
            tsvResultsController.setSelectionIndex(0)
            tableSelectionChanged(tableView)
        }
    }

    /// Drops every row so no view keeps a reference to an object that a
    /// running refresh is about to delete from the database.
    func clearContent() {
        setArrayControllerContent(content: nil)
    }
    
    func getDetailsViewController() -> DetailsViewController {
      let sc: NSSplitViewController = parent?.children[1] as! NSSplitViewController
      let vc: DetailsViewController = sc.children[0] as! DetailsViewController
        return vc
    }
}
