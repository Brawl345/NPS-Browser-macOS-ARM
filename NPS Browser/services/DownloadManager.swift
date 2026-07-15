//
//  DownloadManager.swift
//  NPS Browser
//
//  Created by JK3Y on 5/18/18.
//  Copyright © 2018 JK3Y. All rights reserved.
//

import Cocoa
import CryptoKit
import Queuer
import Alamofire
import Promises
//import Files
import SwiftyUserDefaults

class DownloadManager {
    
    var downloadItems: [DLItem] = []
    let queue = Queuer(name: "DLQueue", maxConcurrentOperationCount: Defaults[.dl_concurrent_downloads], qualityOfService: .default)
    
    init() {
        restoreDownloadList()
    }
    
    func getDestination(data: DLItem) -> DownloadRequest.DownloadFileDestination {
        let destination: DownloadRequest.DownloadFileDestination = { request, response in
            // .pkg filename
            let pathComponent = response.suggestedFilename
                ?? data.downloadUrl?.lastPathComponent
                ?? "download.pkg"

            var path: URL = Defaults[.dl_library_folder]
                ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Downloads")

            if let cf = data.consoleType {
                path.appendPathComponent(cf)
            }
            path.appendPathComponent(pathComponent)

            let decodedurl = path.path.removingPercentEncoding ?? path.path
            let url = URL(fileURLWithPath: decodedurl)
            return (url, [.removePreviousFile, .createIntermediateDirectories])
        }
        return destination
    }
    
    func makeConsoleFolder(dlItem: DLItem) {
        let filepath = Defaults[.dl_library_folder]!
        let console = dlItem.consoleType

        if (try? Folder(path: filepath.path).createSubfolderIfNeeded(withName: console!)) != nil {
            return
        } else {
            Helpers.setupDownloadsDirectory()
            makeConsoleFolder(dlItem: dlItem)
        }
    }
    
    func addToDownloadQueue(data: DLItem) {
        // store request in same object so we can cancel/pause/resume it later
        let destination = getDestination(data: data)
        
        makeConsoleFolder(dlItem: data)
        
        let request = sharedSession.download(data.downloadUrl!, to: destination)
        data.request = request
        data.destination = destination
            
        // add object to downloadItems array
        downloadItems.insert(data, at: 0)
        NotificationCenter.default.post(name: .downloadQueueChanged, object: nil)
        NotificationCenter.default.post(name: .downloadStarted, object: nil)
        
        let downloadItemsIndex = downloadItems.firstIndex(of: data)!
        
        // get object back out of downloadItems array so the async operation can use it and update the properties as it runs
        let dlItem = self.downloadItems[downloadItemsIndex]
        
        let dlFileOperation = makeConcurrentOperation(dlItem: dlItem, request: request)
        self.queue.addOperation(dlFileOperation)
    }
    
    func resumeDownload(data: DLItem) {
      if let resumeData = data.resumeData {
          let request = sharedSession.download(resumingWith: resumeData, to: data.destination)

          data.request = request
          let op = makeConcurrentOperation(dlItem: data, request: request)
          queue.addOperation(op)
      }
    }

    func removeCompleted() {
        for item in downloadItems {
            if (item.isRemovable) {
              downloadItems.remove(at: downloadItems.firstIndex(of: item)!)
            }
        }
    }
    
    func moveToCompleted(item: DLItem) {
        downloadItems.remove(at: downloadItems.firstIndex(of: item)!)
        downloadItems.insert(item, at: downloadItems.endIndex)
    }
    
    func getObjectQueue() -> [DLItem] {
        return self.downloadItems
    }
    
    func stopAndStoreDownloadList() {
        for item in downloadItems {
            
            if (item.status == "Download Complete" || item.status == "Extraction Complete" || item.status == "Missing zRIF, license not created") {
                item.makeViewable()
            } else {
                item.request?.cancel()
                item.status = "Stopped"
                item.makeResumable()
            }
        }
        let downloadList: DownloadList = DownloadList(items: downloadItems)
        
        do {
            let data = try PropertyListEncoder().encode(downloadList)
            UserDefaults.standard.set(data, forKey: "downloads")
        } catch {
            Helpers().makeAlert(messageText: "Save Failed",
                                informativeText: "Download list could not be stored.",
                                alertStyle: .warning)
            
            log.error("Save Failed. Download list could not be stored.")
        }
    }
    
    func restoreDownloadList() {
        let storedData = UserDefaults.standard.object(forKey: "downloads") as? Data
        if (storedData != nil) {
            do {
                let downloadList = try PropertyListDecoder().decode(DownloadList.self, from: storedData!)

                self.downloadItems = downloadList.items
            } catch let error as NSError {
                debugPrint(error)
                
                log.error(error)
            }
        }
    }

    private func verifyChecksum(dlItem: DLItem) {
        guard let expected = dlItem.sha256?.lowercased(),
              expected.count == 64,
              expected.allSatisfy({ $0.isHexDigit }),
              let fileURL = dlItem.destinationURL else {
            proceedAfterDownload(dlItem: dlItem)
            return
        }

        dlItem.status = "Verifying..."
        NotificationCenter.default.post(name: .downloadQueueChanged, object: nil)

        DispatchQueue.global(qos: .utility).async {
            let actual = DownloadManager.sha256OfFile(at: fileURL)
            DispatchQueue.main.async {
                if actual == expected {
                    self.proceedAfterDownload(dlItem: dlItem)
                } else {
                    dlItem.status = "Failed! Checksum mismatch"
                    log.error("SHA256 mismatch for \(dlItem.name ?? "unknown"): expected \(expected), got \(actual ?? "unreadable file")")
                    dlItem.makeRemovable()
                    NotificationCenter.default.post(name: .downloadQueueChanged, object: nil)
                }
            }
        }
    }

    private func proceedAfterDownload(dlItem: DLItem) {
        if (dlItem.isMore()) {
            dlItem.doNext?.cpackPath = dlItem.destinationURL
            dlItem.status = "Waiting..."

            self.addToDownloadQueue(data: dlItem.doNext!)
        } else {
            ExtractionManager(item: dlItem, downloadManager: self).start()
        }
    }

    private static func sha256OfFile(at url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { handle.closeFile() }

        var hasher = SHA256()
        var done = false
        while !done {
            autoreleasepool {
                let chunk = handle.readData(ofLength: 4 * 1024 * 1024)
                if chunk.isEmpty {
                    done = true
                } else {
                    hasher.update(data: chunk)
                }
            }
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    func makeConcurrentOperation(dlItem: DLItem, request: DownloadRequest) -> ConcurrentOperation {
        return ConcurrentOperation { _ in
            dlItem.status = "Queued..."
            
            request.downloadProgress { progress in
                dlItem.status = "Downloading..."
                dlItem.makeStoppable()
                dlItem.progress = (progress.fractionCompleted * 100).rounded()
                dlItem.timeRemaining = progress.fractionCompleted
                NotificationCenter.default.post(name: .downloadQueueChanged, object: nil)
                }
                .responseData { response in
                    response.result.ifSuccess {
                        dlItem.destinationURL = response.destinationURL
                        self.verifyChecksum(dlItem: dlItem)
                    }
                    response.result.ifFailure {
                        guard let resumeData = response.resumeData else {
                            dlItem.status = "Failed! \(response.error!)"
                            if let error = response.error {
                              log.error(error)
                            }

                            dlItem.makeRemovable()
                            return
                        }
                        dlItem.status = "Stopped"
                        dlItem.resumeData = resumeData
                        dlItem.makeResumable()
                    }
            }
        }
    }
}
