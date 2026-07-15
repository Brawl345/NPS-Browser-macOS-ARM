//
//  SharedSession.swift
//  NPS Browser
//

import Foundation
import Alamofire

// Sony ships an incomplete certificate chain on *.playstation.net,
// so evaluation is disabled for those hosts only.
private class PlayStationTrustPolicyManager: ServerTrustPolicyManager {
    override func serverTrustPolicy(forHost host: String) -> ServerTrustPolicy? {
        if host == "playstation.net" || host.hasSuffix(".playstation.net") {
            return .disableEvaluation
        }
        return .performDefaultEvaluation(validateHost: true)
    }
}

let sharedSession: SessionManager = {
    let configuration = URLSessionConfiguration.default
    return SessionManager(
        configuration: configuration,
        serverTrustPolicyManager: PlayStationTrustPolicyManager(policies: [:])
    )
}()
