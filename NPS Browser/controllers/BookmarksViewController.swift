//
//  BookmarksViewController.swift
//  NPS Browser
//
//  Created by JK3Y on 6/9/18.
//  Copyright © 2018 JK3Y. All rights reserved.
//

import Cocoa

class BookmarksViewController: NSViewController {
    
    @IBOutlet weak var tableView: NSTableView!
    
    @IBOutlet var bookmarksArrayController: NSArrayController!

    override func viewDidLoad() {
        super.viewDidLoad()
        updateView()
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        updateView()
    }
    
    @IBAction func doRemoveBookmark(_ sender: NSButton) {
        let bookmark = Helpers().getRowObjectFromTableRowButton(sender) as! Bookmark
        let uuid = bookmark.uuid

        let storedBookmark = DBManager().fetch(Bookmark.self, predicate: NSPredicate(format: "uuid == %@", uuid!)).first
        
        DBManager().delete(object: storedBookmark!)

        Helpers().getDataController().getDetailsViewController().toggleBookmark(comparePK: uuid!)

        updateView()
    }
    
    func updateView() {
        let content = DBManager().fetch(Bookmark.self)
        bookmarksArrayController.content = content
        bookmarksArrayController.rearrangeObjects()
        if !content.isEmpty {
            bookmarksArrayController.setSelectionIndex(0)
        }
    }
}
