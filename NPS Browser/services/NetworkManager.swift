//
//  NetworkManager.swift
//  NPS Browser
//
//  Created by JK3Y on 8/10/18.
//  Copyright © 2018 JK3Y. All rights reserved.
//

import Foundation
import CryptoKit
import Promises
import Alamofire
import SwiftyUserDefaults

enum NetworkError: LocalizedError {
    case invalidUpdateXML

    var errorDescription: String? {
        switch self {
        case .invalidUpdateXML: return "The update XML could not be parsed."
        }
    }
}

class NetworkManager {

    let windowDelegate: WindowDelegate = Helpers().getWindowDelegate()
    
    let itemType = Helpers().getWindowDelegate().getItemType()

    func makeRequest() {
        guard let url = Helpers().getUrlSettingsByType(itemType: itemType) else {
            Helpers().makeAlert(messageText: "No URL set for \(self.itemType.console.rawValue) \(self.itemType.fileType.rawValue)s.", informativeText: "Set source paths in the preferences window.", alertStyle: .warning)

            log.error("Invalid URL given for item type: \(itemType.description)")
            return
        }
        
        if (url.isFileURL) {
            guard (try? url.checkResourceIsReachable()) != nil else {
                Helpers().makeAlert(messageText: "Resource not found!", informativeText: "File does not exist at path: \(url)", alertStyle: .warning)
                return
            }
        }

        let ft:FileType = self.windowDelegate.getItemType().fileType
        let ct:ConsoleType = self.windowDelegate.getItemType().console
        let workQueue = DispatchQueue.global(qos: .userInitiated)

        Promise<[TSVData]> { fulfill, reject in
            Helpers().showLoadingViewController()
            Helpers().getLoadingViewController().setLabel(text: "Requesting data... (step 1/5)")
            Helpers().getLoadingViewController().setProgress(amount: 10)

            sharedSession.request(url)
                .downloadProgress { progress in
                    self.windowDelegate.getLoadingViewController().setLabel(text: "Receiving data... (step 2/5)")
                    self.windowDelegate.getLoadingViewController().setProgress(amount: 10 + progress.fractionCompleted * 40)
                }

                .responseString(queue: workQueue) { response in
                    switch response.result {
                    case .success(let text):
                        DispatchQueue.main.async {
                            self.windowDelegate.getLoadingViewController().setLabel(text: "Preparing... (step 3/5)")
                            self.windowDelegate.getLoadingViewController().setProgress(amount: 60)
                        }
                        let parsedTSV = Parser().parseTSV(data: text, itemType: self.itemType)
                        fulfill(parsedTSV)
                    case .failure(let error):
                        reject(error)
                    }
            }
        }
            .then(on: workQueue) { (_: [TSVData]) in
                DispatchQueue.main.async {
                    self.windowDelegate.getLoadingViewController().setLabel(text: "Removing old values... (step 4/5)")
                    self.windowDelegate.getLoadingViewController().setProgress(amount: 75)
                }

                let storage = try RealmStorageContext()
                try storage.deleteAll(Item.self, predicate: NSPredicate(format: "fileType == %@ AND consoleType == %@", ft.rawValue, ct.rawValue))
        }
            .then(on: workQueue) { (result: [TSVData]) in
                DispatchQueue.main.async {
                    self.windowDelegate.getLoadingViewController().setLabel(text: "Storing new values... (step 5/5)")
                    self.windowDelegate.getLoadingViewController().setProgress(amount: 90)
                }

                let objs = result.map { item in
                    return Item(tsvData: item)
                }
                DBManager().storeBulk(objArray: objs)
        }
            .then { _ in
                Helpers().getLoadingViewController().closeWindow()
        }
            .then { _ in
                if (self.itemType.console == ConsoleType.PSV && self.itemType.fileType == FileType.Game) {

                    guard let cpackurl = Defaults[.src_compatPacks] else {
                        Helpers().makeAlert(messageText: "No URL set for Compat Packs.", informativeText: "Set source paths in the preferences window.", alertStyle: .warning)
                        
                        log.error("Invalid URL given for compat packs.")
                        return
                    }
                    
                    guard let cpatchurl: URL = Defaults[.src_compatPatch] else {
                        Helpers().makeAlert(messageText: "No URL set for Compat Patches.", informativeText: "Set source paths in the preferences window.", alertStyle: .warning)
                        
                        log.error("Invalid URL given for compat patches")
                        return
                    }
                        
                    if (cpatchurl.isFileURL) {
                        guard (try? cpatchurl.checkResourceIsReachable()) != nil else {
                            Helpers().makeAlert(messageText: "Resource not found!", informativeText: "File does not exist at path: \(cpatchurl)", alertStyle: .warning)
                            return
                        }
                    }

                
                    self.makeCompatPackRequestPromise(url: cpackurl, isPatch: false)
                    .then {_ in
                        self.makeCompatPackRequestPromise(url: cpatchurl, isPatch: true)
                    }
                    
                }
        }
            .then {_ in
                Helpers().getDataController().filterType(itemType: ItemType(console: ct, fileType: ft), region: self.windowDelegate.getRegion())
        }
            .catch { error in
                log.error(error)
                Helpers().getLoadingViewController().closeWindow()
                Helpers().makeAlert(messageText: "Request failed",
                                    informativeText: error.localizedDescription,
                                    alertStyle: .warning)
        }
    }

    func makeCompatPackRequestPromise(url: URL, isPatch: Bool) -> Promise<[CompatPack]?> {
        if url.absoluteString.isEmpty {
            return Promise(nil)
        }
        
        var typeName: String = "CompatPack"
        if isPatch {
            typeName = "CompatPatch"
        }
        let workQueue = DispatchQueue.global(qos: .userInitiated)
        return Promise<[CompatPack]?> { fulfill, reject in
            
          if (self.windowDelegate.getLoadingViewController().presentingViewController != nil) {
                Helpers().showLoadingViewController()
            }
            Helpers().getLoadingViewController().setLabel(text: "Requesting Comp Packs... (step 1/5)")
            Helpers().getLoadingViewController().setProgress(amount: 10)

            sharedSession.request(url)
                .downloadProgress { progress in
                    self.windowDelegate.getLoadingViewController().setLabel(text: "Receiving data... (step 2/5)")
                    self.windowDelegate.getLoadingViewController().setProgress(amount: 10 + progress.fractionCompleted * 40)
                }
                .responseString(queue: workQueue) { response in
                    switch response.result {
                    case .success(let text):
                        DispatchQueue.main.async {
                            self.windowDelegate.getLoadingViewController().setLabel(text: "Preparing... (step 3/5)")
                            self.windowDelegate.getLoadingViewController().setProgress(amount: 60)
                        }
                        let parsed = Parser().parseCompatPackEntries(data: text, isPatch: isPatch, typeName: typeName)
                        fulfill(parsed)
                    case .failure(let error):
                        reject(error)
                    }
                }
            }
            .then(on: workQueue) { (_: [CompatPack]?) in
                DispatchQueue.main.async {
                    self.windowDelegate.getLoadingViewController().setLabel(text: "Removing old values... (step 4/5)")
                    self.windowDelegate.getLoadingViewController().setProgress(amount: 75)
                }

                let storage = try RealmStorageContext()
                try storage.deleteAll(CompatPack.self, predicate: NSPredicate(format: "type == %@", typeName))
            }
            .then(on: workQueue) { (result: [CompatPack]?) in
                DispatchQueue.main.async {
                    self.windowDelegate.getLoadingViewController().setLabel(text: "Storing new values... (step 5/5)")
                    self.windowDelegate.getLoadingViewController().setProgress(amount: 90)
                }
                if let result = result {
                    DBManager().storeBulk(objArray: result)
                }
            }
            .then { _ in
                Helpers().getLoadingViewController().closeWindow()
        }
            .catch { error in
                log.error(error)
                Helpers().getLoadingViewController().closeWindow()
                Helpers().makeAlert(messageText: "Compat pack request failed",
                                    informativeText: error.localizedDescription,
                                    alertStyle: .warning)
        }
    }

    func getUpdateXMLURLFromHMAC(titleId: String) -> String? {
        let key = SymmetricKey(data: Data([
            0xE5, 0xE2, 0x78, 0xAA, 0x1E, 0xE3, 0x40, 0x82, 0xA0, 0x88, 0x27, 0x9C, 0x83, 0xF9, 0xBB, 0xC8,
            0x06, 0x82, 0x1C, 0x52, 0xF2, 0xAB, 0x5D, 0x2B, 0x4A, 0xBD, 0x99, 0x54, 0x50, 0x35, 0x51, 0x14
        ]))

        let hmac = HMAC<SHA256>.authenticationCode(for: Data("np_\(titleId)".utf8), using: key)
        let hash = hmac.map { String(format: "%02x", $0) }.joined()

        return "https://gs-sec.ww.np.dl.playstation.net/pl/np/\(titleId)/\(hash)/\(titleId)-ver.xml"
    }

    func fetchUpdateXML(url: String) -> (() -> (Promise<URL>)) {

        log.debug(url)

        return {
                Promise<URL> { fulfill, reject in
                sharedSession.request(url)
                    .responseString { response in
                        switch response.result {
                        case .success(let data):
                            if let updateurl = Parser().parseUpdateXML(data: data) {
                                fulfill(updateurl)
                            } else {
                                reject(NetworkError.invalidUpdateXML)
                            }
                        case .failure(let error):
                            reject(error)
                        }
                }
            }
        }

    }
    
}
