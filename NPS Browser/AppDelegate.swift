//
//  AppDelegate.swift
//  NPS Browser
//
//  Created by JK3Y on 4/28/18.
//  Copyright © 2018 JK3Y. All rights reserved.
//

import Cocoa
import SwiftyBeaver
import RealmSwift
import SwiftyUserDefaults
import UserNotifications

let log = SwiftyBeaver.self

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {

    lazy var downloadManager: DownloadManager = DownloadManager()
    private var dockProgressController: DockProgressController?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        setupSwiftyBeaverLogging()
        Helpers.restoreFolderAccess(key: .dl_library_bookmark)
        Helpers.restoreFolderAccess(key: .xt_library_bookmark)
        promptForLibraryFolderIfNeeded()
        migrateSourceURLsToHTTPS()
        setupNotifications()
        dockProgressController = DockProgressController(downloadManager: downloadManager)
    }

    func promptForLibraryFolderIfNeeded() {
        guard Defaults[.dl_library_bookmark] == nil else { return }

        let panel = NSOpenPanel()
        panel.message = "Choose a folder where NPS Browser saves downloads and extracted files."
        panel.prompt = "Choose"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first

        guard panel.runModal() == .OK, let url = panel.urls.first else { return }

        Defaults[.dl_library_location] = url
        Defaults[.dl_library_folder] = url
        Helpers.storeFolderBookmark(url: url, key: .dl_library_bookmark)

        if Defaults[.xt_library_bookmark] == nil {
            Defaults[.xt_library_location] = url
            Defaults[.xt_library_folder] = url
            Helpers.storeFolderBookmark(url: url, key: .xt_library_bookmark)
        }
    }

    func setupNotifications() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                log.error("Notification authorization failed: \(error)")
            }
        }
    }

    func migrateSourceURLsToHTTPS() {
        let sourceKeys: [DefaultsKey<URL?>] = [
            .src_psv_games, .src_psv_dlcs, .src_psv_themes,
            .src_psp_games, .src_psx_games,
            .src_ps3_games, .src_ps3_dlcs, .src_ps3_themes, .src_ps3_avatars,
            .src_compatPacks, .src_compatPatch
        ]

        for key in sourceKeys {
            guard let url = Defaults[key],
                  url.scheme == "http",
                  url.host == "nopaystation.com",
                  var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
                continue
            }
            components.scheme = "https"
            if let migrated = components.url {
                Defaults[key] = migrated
            }
        }
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        downloadManager.cancelActiveDownloads()
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    func setupSwiftyBeaverLogging() {
        let console = ConsoleDestination()
        let file = FileDestination()

        log.addDestination(console)
        log.addDestination(file)
    }
    
    // MARK: - Notifications
    
    func showNotification(title: String, subtitle: String) {
      let content = UNMutableNotificationContent()
      content.title = title
      content.subtitle = subtitle
      content.sound = UNNotificationSound.default

      let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
      UNUserNotificationCenter.current().add(request) { (error) in
        if let error = error {
          log.error("Error showing notification: \(error)")
        }
      }
    }
    
    // Delegate method for notification presentation (optional)
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
      // Customize notification presentation here
      completionHandler([.banner, .sound]) // Allow banner and sound
    }
}

