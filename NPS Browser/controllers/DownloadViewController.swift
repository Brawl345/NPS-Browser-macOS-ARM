//
//  DownloadViewController.swift
//  NPS Browser
//

import Cocoa

extension Notification.Name {
    static let downloadQueueChanged = Notification.Name("downloadQueueChanged")
    static let downloadStarted     = Notification.Name("downloadStarted")
}

class DownloadViewController: NSViewController {

    @IBOutlet weak var dlTableView: NSTableView!
    @IBOutlet var dlArrayController: NSArrayController!

    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(updateView), name: .downloadQueueChanged, object: nil)
        updateView()
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        updateView()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc func updateView() {
        let content = Helpers().getSharedAppDelegate().downloadManager.getObjectQueue()
        dlArrayController.content = content
        dlArrayController.rearrangeObjects()
        if !content.isEmpty {
            dlArrayController.setSelectionIndex(0)
        }
    }

    @IBAction func clearCompleted(_ sender: Any) {
        Helpers().getSharedAppDelegate().downloadManager.removeCompleted()
        updateView()
    }
}
