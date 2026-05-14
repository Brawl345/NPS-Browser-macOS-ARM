//
//  SharedSession.swift
//  NPS Browser
//

import Foundation
import Alamofire

private class TrustAllPolicyManager: ServerTrustPolicyManager {
    override func serverTrustPolicy(forHost host: String) -> ServerTrustPolicy? {
        return .disableEvaluation
    }
}

let sharedSession: SessionManager = {
    let configuration = URLSessionConfiguration.default
    return SessionManager(
        configuration: configuration,
        serverTrustPolicyManager: TrustAllPolicyManager(policies: [:])
    )
}()
