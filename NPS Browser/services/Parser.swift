//
//  Parser.swift
//  NPS Browser
//
//  Created by JK3Y on 8/3/18.
//  Copyright © 2018 JK3Y. All rights reserved.
//

import Foundation
import Fuzi

class Parser {
    func parseTSV(data: String, itemType: ItemType) -> [TSVData] {
        var parsedData: [TSVData] = []
        let rows = data.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard !rows.isEmpty else { return parsedData }
        parsedData.reserveCapacity(rows.count - 1)

        for row in rows.dropFirst() {
            let values = row.components(separatedBy: "\t")
            guard values.count > 1 else { continue }

            let tsvData = TSVData(type: itemType, values: values)

            parsedData.append(tsvData)
        }
        return parsedData
    }
    
    func parseCompatPackEntries(data: String, isPatch: Bool = false, typeName: String) -> [CompatPack] {
        var parsedData: [CompatPack] = []
        let rows = data.components(separatedBy: .newlines).filter { !$0.isEmpty }
        let baseURL = "https://gitlab.com/nopaystation_repos/nps_compati_packs/raw/master/"

        for row in rows {
            let components = row.components(separatedBy: "=")
            let path = components.first ?? ""
            let pathComponents = path.components(separatedBy: "/")
            let titleIdIndex = isPatch ? 1 : 0
            guard pathComponents.indices.contains(titleIdIndex) else { continue }
            let title_id = pathComponents[titleIdIndex]

            let pack = CompatPack()
            pack.titleId = title_id
            pack.downloadUrl = "\(baseURL)\(path)"
            pack.type = typeName

            parsedData.append(pack)
        }
        return parsedData
    }

    func parseUpdateXML(data: String) -> URL? {
        let xml = data
        var x: String = ""

        // Titles without an update return an empty body
        if xml.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return nil
        }

        do {
            let document = try XMLDocument(string: xml)
            
            if let root = document.root {
                guard let lastpkg = root.firstChild(tag: "tag")?.children.last else {
                    return nil
                }

                if let hp = lastpkg.firstChild(tag: "hybrid_package") {
                    x = hp.attributes["url"] ?? ""
                } else {
                    x = lastpkg.attributes["url"] ?? ""
                }
            }
        } catch let error {
            log.error(error)
        }
        
        return URL(string: x)
    }
}
