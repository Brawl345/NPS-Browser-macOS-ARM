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
            .responseJSON { response in
                guard response.result.isSuccess, let data = response.data else {
                    if let error = response.error {
                        log.error(error)
                    }
                    return
                }

                guard let latestRelease = try? newJSONDecoder().decode(GHLatestRelease.self, from: data),
                      let asset = latestRelease.assets.first else {
                    log.error("Could not decode latest release info from GitHub.")
                    return
                }

                let ghVersion = latestRelease.tagName.replacingOccurrences(of: "v", with: "")
                successHandler(ghVersion, asset.browserDownloadURL)
        }
    }
    
    func downloadUpdate(url: URL) {
        
        Helpers().showLoadingViewController()
        Helpers().getLoadingViewController().setLabel(text: "Fetching update...")
        
        let destination: DownloadRequest.DownloadFileDestination = { request, response in
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
                response.result.ifSuccess {
                    Helpers().makeAlert(messageText: "Update Downloaded", informativeText: "Update has been downloaded.", alertStyle: .informational)
                }
                response.result.ifFailure {
                    Helpers().makeAlert(messageText: "Download failed", informativeText: "The update has failed to download.", alertStyle: .warning)
                }
                
                Helpers().getLoadingViewController().closeWindow()
        }
    }
    
}
