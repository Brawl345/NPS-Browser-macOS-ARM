//
//  TSVData.swift
//  NPS Browser
//
//  Created by JK3Y on 8/4/18.
//  Copyright © 2018 JK3Y. All rights reserved.
//

import Foundation

struct TSVData {
    var titleId                 : String?
    var region                  : String?
    var name                    : String?
    var pkgDirectLink           : String?
    var lastModificationDate    : Date?
    var fileSize                : Int64?
    var sha256                  : String?
    var zrif                    : String?
    var contentId               : String?
    var originalName            : String?
    var requiredFw              : Float?
    var rap                     : String?
    var downloadRapFile         : String?
    var consoleType             : ConsoleType
    var fileType                : FileType
    
    init(type: ItemType, values: [String]) {
        func col(_ index: Int) -> String? {
            guard values.indices.contains(index) else { return nil }
            return values[index]
        }

        consoleType = type.console
        fileType = type.fileType
        titleId = col(0)
        region = col(1)

        switch type.console {
        case .PSV:
            switch type.fileType {
            case .Game:
                name                  = col(2)
                pkgDirectLink         = col(3)
                zrif                  = col(4)
                contentId             = col(5)
                lastModificationDate  = parseDate(dateString: col(6))
                originalName          = col(7)
                fileSize              = Int64(col(8) ?? "")
                sha256                = col(9)
                requiredFw            = Float(col(10) ?? "")
            case .DLC, .Theme:
                name                  = col(2)
                pkgDirectLink         = col(3)
                zrif                  = col(4)
                contentId             = col(5)
                lastModificationDate  = parseDate(dateString: col(6))
                fileSize              = Int64(col(7) ?? "")
                sha256                = col(8)
            default: break
            }
        case .PS3:
            let baseURL = "https://nopaystation.com/tools/rap2file"
            name                      = col(2)
            pkgDirectLink             = col(3)
            rap                       = col(4)
            contentId                 = col(5)
            lastModificationDate      = parseDate(dateString: col(6))
            if let contentId = col(5), let rap = col(4) {
                downloadRapFile       = "\(baseURL)/\(contentId)/\(rap)"
            }
            fileSize                  = Int64(col(8) ?? "")
            sha256                    = col(9)
        case .PSP:
            name                      = col(3)
            pkgDirectLink             = col(4)
            contentId                 = col(5)
            lastModificationDate      = parseDate(dateString: col(6))
            rap                       = col(7)
            downloadRapFile           = col(8)
            fileSize                  = Int64(col(9) ?? "")
            sha256                    = col(10)
        case .PSX:
            name                      = col(2)
            pkgDirectLink             = col(3)
            contentId                 = col(4)
            lastModificationDate      = parseDate(dateString: col(5))
            originalName              = col(6)
            fileSize                  = Int64(col(7) ?? "")
            sha256                    = col(8)
        }
    }

    func parseDate(dateString: String?) -> Date? {
        guard let dateString = dateString else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        guard let date = formatter.date(from: dateString) else {
            return nil
        }
        return date
    }
}
