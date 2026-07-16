//
//  SharedSession.swift
//  NPS Browser
//

import Foundation
import Alamofire

// Sony ships an incomplete certificate chain on *.playstation.net,
// so evaluation is disabled for those hosts only.
private final class PlayStationTrustManager: ServerTrustManager, @unchecked Sendable {
    override func serverTrustEvaluator(forHost host: String) throws -> ServerTrustEvaluating? {
        if host == "playstation.net" || host.hasSuffix(".playstation.net") {
            return DisabledTrustEvaluator()
        }
        return DefaultTrustEvaluator()
    }
}

let sharedSession: Session = {
    let configuration = URLSessionConfiguration.default
    return Session(
        configuration: configuration,
        serverTrustManager: PlayStationTrustManager(allHostsMustBeEvaluated: false, evaluators: [:])
    )
}()
