//
//  DLItem.swift
//  NPS Browser
//
//  Created by JK3Y on 5/19/18.
//  Copyright © 2018 JK3Y. All rights reserved.
//

import AppKit
import Alamofire

enum DLStatus {
    static let queued               = "Queued..."
    static let downloading          = "Downloading..."
    static let waiting              = "Waiting..."
    static let stopped              = "Stopped"
    static let verifying            = "Verifying..."
    static let extracting           = "Extracting..."
    static let downloadComplete     = "Download Complete"
    static let extractionComplete   = "Extraction Complete"
    static let extractionFailed     = "Extraction failed"
    static let missingZrif          = "Missing zRIF, license not created"
    static let checksumMismatch     = "Failed! Checksum mismatch"
}

struct DownloadList: Codable {
    // Bumped to 2 with Alamofire 5: AF4 resume data is incompatible
    // and gets discarded when restoring a version-1 list
    static let currentSchemaVersion = 2

    var items: [DLItem]
    var schemaVersion: Int

    init(items: [DLItem]) {
        self.items = items
        self.schemaVersion = Self.currentSchemaVersion
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        items = try container.decode([DLItem].self, forKey: .items)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
    }
}

class DLItem: NSObject, Codable {
    @objc dynamic var titleId          : String?
    @objc dynamic var name              : String?
    @objc dynamic var downloadUrl     : URL?
    @objc dynamic var progress          : Double = 0.0
    @objc dynamic var zrif              : String?
    @objc dynamic var sha256            : String?
    @objc dynamic var status            : String?
    @objc dynamic var timeRemaining     : TimeInterval = 0
    var request                         : DownloadRequest?
    var resumeData                      : Data?
    var completedBytes                  : Int64 = 0
    var totalBytes                      : Int64 = 0
    var destination                     : DownloadRequest.Destination?
    @objc dynamic var destinationURL    : URL?
    @objc dynamic var isStoppable      : Bool = false
    @objc dynamic var isViewable        : Bool = false
    @objc dynamic var isRemovable       : Bool = false
    @objc dynamic var isResumable       : Bool = false
    @objc dynamic var cpackPath         : URL?
    @objc dynamic var doNext            : DLItem? = nil
    @objc dynamic var parentItem        : DLItem? = nil
    @objc dynamic var consoleType       : String?
    @objc dynamic var fileType          : String?
    @objc dynamic var actionImage: NSImage?
    
    enum CodingKeys: String, CodingKey {
        case titleId
        case name
        case downloadUrl
        case progress
        case zrif
        case sha256
        case status
        case timeRemaining
        case resumeData
        case destinationURL
        case isStoppable
        case isViewable
        case isRemovable
        case isResumable
        case cpackPath
        case doNext
        case parentItem
        case consoleType
        case fileType
    }
    
    override init() {
        super.init()
    }
    
    func isMore() -> Bool {
        return doNext != nil
    }
    
    func makeStoppable() {
        self.isStoppable    = true
        self.isRemovable    = false
        self.isResumable    = false
        self.isViewable     = false
        
        actionImage = #imageLiteral(resourceName: "Stop")
    }
    
    func makeViewable() {
        self.isViewable     = true
        self.isRemovable    = true
        self.isStoppable    = false
        self.isResumable    = false
        
        actionImage = #imageLiteral(resourceName: "Reveal")
    }
    
    func makeResumable() {
        self.isResumable    = true
        self.isRemovable    = true
        self.isStoppable    = false
        self.isViewable     = false
        
        actionImage = #imageLiteral(resourceName: "Start")
    }
    
    func makeRemovable() {
        self.isRemovable    = true
        self.isResumable    = false
        self.isStoppable    = false
        self.isViewable     = false
        
        actionImage = #imageLiteral(resourceName: "Reveal")
    }

}
