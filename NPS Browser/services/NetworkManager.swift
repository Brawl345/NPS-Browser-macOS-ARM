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
import RealmSwift
import SwiftyUserDefaults

final class GameUpdateService {
    static let shared = GameUpdateService()

    enum Availability {
        case available(URL)
        case unavailable
    }

    // Main-thread only: filled and read from Alamofire's main-queue completions
    private var cache: [String: Availability] = [:]

    func cachedAvailability(titleId: String) -> Availability? {
        return cache[titleId]
    }

    func cachedUpdateURL(titleId: String) -> URL? {
        if case .available(let url)? = cache[titleId] {
            return url
        }
        return nil
    }

    func checkAvailability(titleId: String, completion: @escaping (Availability?) -> Void) {
        if let cached = cache[titleId] {
            completion(cached)
            return
        }

        sharedSession.request(Self.updateXMLURL(titleId: titleId))
            .responseString(encoding: .utf8) { [weak self] response in
                switch response.result {
                case .success(let body):
                    let availability: Availability
                    if let url = Parser().parseUpdateXML(data: body) {
                        availability = .available(url)
                    } else {
                        availability = .unavailable
                    }
                    self?.cache[titleId] = availability
                    completion(availability)
                case .failure(let error):
                    log.error(error)
                    completion(nil)
                }
            }
    }

    private static func updateXMLURL(titleId: String) -> String {
        let key = SymmetricKey(data: Data([
            0xE5, 0xE2, 0x78, 0xAA, 0x1E, 0xE3, 0x40, 0x82, 0xA0, 0x88, 0x27, 0x9C, 0x83, 0xF9, 0xBB, 0xC8,
            0x06, 0x82, 0x1C, 0x52, 0xF2, 0xAB, 0x5D, 0x2B, 0x4A, 0xBD, 0x99, 0x54, 0x50, 0x35, 0x51, 0x14
        ]))

        let hmac = HMAC<SHA256>.authenticationCode(for: Data("np_\(titleId)".utf8), using: key)
        let hash = hmac.map { String(format: "%02x", $0) }.joined()

        return "https://gs-sec.ww.np.dl.playstation.net/pl/np/\(titleId)/\(hash)/\(titleId)-ver.xml"
    }
}

class NetworkManager {

    let windowDelegate: WindowDelegate = Helpers().getWindowDelegate()

    private static let refreshInterval: TimeInterval = 24 * 60 * 60
    private static let parallelDownloads = 3
    private static var isRefreshing = false

    static func lastRefreshKey(_ itemType: ItemType) -> DefaultsKey<Date?> {
        return DefaultsKey<Date?>("refresh_\(itemType.console.rawValue)_\(itemType.fileType.rawValue)")
    }

    private func isOutdated(_ itemType: ItemType) -> Bool {
        guard let last = Defaults[NetworkManager.lastRefreshKey(itemType)] else { return true }
        return Date().timeIntervalSince(last) > NetworkManager.refreshInterval
    }

    private func hasStoredItems(_ itemType: ItemType) -> Bool {
        let predicate = NSPredicate(format: "consoleType == %@ AND fileType == %@",
                                    itemType.console.rawValue, itemType.fileType.rawValue)
        return try! Realm().objects(Item.self).filter(predicate).first != nil
    }

    /// Downloads every source whose data is missing or older than a day.
    /// `force` reloads all of them regardless of their age.
    func refreshAll(force: Bool = false) {
        guard !NetworkManager.isRefreshing else { return }

        let pending = ItemType.allDownloadable.filter { force || isOutdated($0) || !hasStoredItems($0) }
        guard !pending.isEmpty else { return }

        NetworkManager.isRefreshing = true
        Helpers().getDataController().clearContent()
        Helpers().showLoadingViewController()
        setStatus(text: "Updating \(pending.count) sources...", progress: 0)

        let batches = stride(from: 0, to: pending.count, by: NetworkManager.parallelDownloads).map {
            Array(pending[$0 ..< min($0 + NetworkManager.parallelDownloads, pending.count)])
        }

        runBatches(batches, index: 0, done: 0, total: pending.count)
    }

    private func runBatches(_ batches: [[ItemType]], index: Int, done: Int, total: Int) {
        guard index < batches.count else {
            finishRefresh()
            return
        }

        let batch = batches[index]
        setStatus(text: "Downloading \(batch.map { $0.label }.joined(separator: ", "))...",
                  progress: Double(done) / Double(total) * 90)

        all(batch.map { self.fetchAndStore(itemType: $0) })
            .then { _ in
                self.runBatches(batches, index: index + 1, done: done + batch.count, total: total)
            }
            .catch { error in
                log.error(error)
                self.finishRefresh()
                Helpers().makeAlert(messageText: "Request failed",
                                    informativeText: error.localizedDescription,
                                    alertStyle: .warning)
            }
    }

    private func finishRefresh() {
        setStatus(text: "Loading compatibility packs...", progress: 90)

        let compatPacks = Defaults[.src_compatPacks]
        let compatPatch = Defaults[.src_compatPatch]

        makeCompatPackRequestPromise(url: compatPacks, isPatch: false)
            .then { _ in
                self.makeCompatPackRequestPromise(url: compatPatch, isPatch: true)
            }
            .always {
                NetworkManager.isRefreshing = false
                Helpers().getLoadingViewController().closeWindow()
                Helpers().getDataController().applyFilter()
            }
    }

    private func setStatus(text: String, progress: Double) {
        DispatchQueue.main.async {
            self.windowDelegate.getLoadingViewController().setLabel(text: text)
            self.windowDelegate.getLoadingViewController().setProgress(amount: progress)
        }
    }

    private func fetchAndStore(itemType: ItemType) -> Promise<Void> {
        guard let url = Helpers().getUrlSettingsByType(itemType: itemType) else {
            log.error("Invalid URL given for item type: \(itemType.description)")
            return Promise(())
        }

        if url.isFileURL, (try? url.checkResourceIsReachable()) == nil {
            log.error("File does not exist at path: \(url)")
            return Promise(())
        }

        let workQueue = DispatchQueue.global(qos: .userInitiated)

        return Promise<[TSVData]> { fulfill, reject in
            sharedSession.request(url)
                .responseString(queue: workQueue, encoding: .utf8) { response in
                    switch response.result {
                    case .success(let text):
                        fulfill(Parser().parseTSV(data: text, itemType: itemType))
                    case .failure(let error):
                        reject(error)
                    }
                }
        }
            .then(on: workQueue) { (result: [TSVData]) -> Void in
                let storage = try RealmStorageContext()
                try storage.deleteAll(Item.self, predicate: NSPredicate(format: "fileType == %@ AND consoleType == %@",
                                                                        itemType.fileType.rawValue, itemType.console.rawValue))

                DBManager().storeBulk(objArray: result.map { Item(tsvData: $0) })

                DispatchQueue.main.async {
                    Defaults[NetworkManager.lastRefreshKey(itemType)] = Date()
                }
            }
    }

    func makeCompatPackRequestPromise(url: URL?, isPatch: Bool) -> Promise<Void> {
        guard let url = url, !url.absoluteString.isEmpty else {
            return Promise(())
        }

        let typeName = isPatch ? "CompatPatch" : "CompatPack"
        let workQueue = DispatchQueue.global(qos: .userInitiated)

        return Promise<[CompatPack]> { fulfill, reject in
            sharedSession.request(url)
                .responseString(queue: workQueue, encoding: .utf8) { response in
                    switch response.result {
                    case .success(let text):
                        fulfill(Parser().parseCompatPackEntries(data: text, isPatch: isPatch, typeName: typeName))
                    case .failure(let error):
                        reject(error)
                    }
                }
            }
            .then(on: workQueue) { (result: [CompatPack]) -> Void in
                let storage = try RealmStorageContext()
                try storage.deleteAll(CompatPack.self, predicate: NSPredicate(format: "type == %@", typeName))

                DBManager().storeBulk(objArray: result)
            }
            .recover { error -> Void in
                log.error(error)
            }
    }

}
