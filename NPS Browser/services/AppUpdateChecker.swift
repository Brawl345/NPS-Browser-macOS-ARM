//
//  AppUpdateChecker.swift
//  NPS Browser
//
//  Created by JK3Y on 8/12/18.
//  Copyright © 2018 JK3Y. All rights reserved.
//

import Foundation
import Promises
import Alamofire

class AppUpdateChecker {
    
    func fetchLatest(successHandler: @escaping ((_ tagName: String, _ browserDownloadURL: String) -> ()) ) {
        let url = "https://api.github.com/repos/JK3Y/NPS-Browser-macOS/releases/latest"
        
        sharedSession.request(url)
            .responseDecodable(of: GHLatestRelease.self, decoder: newJSONDecoder()) { response in
                switch response.result {
                case .success(let latestRelease):
                    guard let asset = latestRelease.assets.first else {
                        log.error("Latest GitHub release has no assets.")
                        return
                    }

                    let ghVersion = latestRelease.tagName.replacingOccurrences(of: "v", with: "")
                    successHandler(ghVersion, asset.browserDownloadURL)
                case .failure(let error):
                    log.error(error)
                }
        }
    }
    
    func downloadUpdate(url: URL) {
        
        Helpers().showLoadingViewController()
        Helpers().getLoadingViewController().setLabel(text: "Fetching update...")
        
        let destination: DownloadRequest.Destination = { request, response in
            let pathComponent = response.suggestedFilename ?? url.lastPathComponent
            var target: URL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Downloads")
            target.appendPathComponent(pathComponent)

            return (target, [.removePreviousFile, .createIntermediateDirectories])
        }
        
        sharedSession.download(url, to: destination)
            .downloadProgress { progress in
                Helpers().getLoadingViewController().setLabel(text: "Downloading...")
                Helpers().getLoadingViewController().setProgress(amount: progress.fractionCompleted * 100)
        }
            .responseString { response in
                switch response.result {
                case .success:
                    Helpers().makeAlert(messageText: "Update Downloaded", informativeText: "Update has been downloaded.", alertStyle: .informational)
                case .failure:
                    Helpers().makeAlert(messageText: "Download failed", informativeText: "The update has failed to download.", alertStyle: .warning)
                }

                Helpers().getLoadingViewController().closeWindow()
        }
    }
    
}
