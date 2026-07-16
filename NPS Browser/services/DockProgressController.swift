//
//  DockProgressController.swift
//  NPS Browser
//

import Cocoa

final class DockProgressController {
    private let downloadManager: DownloadManager
    private let progressBar = NSProgressIndicator()
    private var tileView: NSImageView?
    private var lastDisplay = Date.distantPast
    private var lastFraction = -1.0
    private var isVisible = false

    init(downloadManager: DownloadManager) {
        self.downloadManager = downloadManager

        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(queueChanged), name: .downloadQueueChanged, object: nil)
        nc.addObserver(self, selector: #selector(progressChanged), name: .downloadProgressChanged, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func queueChanged() {
        refresh(force: true)
    }

    @objc private func progressChanged() {
        refresh(force: false)
    }

    private func refresh(force: Bool) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { self.refresh(force: force) }
            return
        }

        let (fraction, activeCount) = downloadManager.overallProgress()
        guard activeCount > 0 else {
            hide()
            return
        }

        // dockTile.display() is expensive; skip ticks that change little
        if !force,
           Date().timeIntervalSince(lastDisplay) < 0.2,
           abs(fraction - lastFraction) < 0.01 {
            return
        }

        show(fraction: fraction, activeCount: activeCount)
    }

    private func show(fraction: Double, activeCount: Int) {
        let tile = NSApp.dockTile

        if tileView == nil {
            let imageView = NSImageView(frame: NSRect(origin: .zero, size: tile.size))
            imageView.imageScaling = .scaleProportionallyUpOrDown
            imageView.image = NSApp.applicationIconImage

            progressBar.style = .bar
            progressBar.isIndeterminate = false
            progressBar.minValue = 0
            progressBar.maxValue = 1
            imageView.addSubview(progressBar)

            tileView = imageView
        }

        tileView?.frame = NSRect(origin: .zero, size: tile.size)
        progressBar.frame = NSRect(x: tile.size.width * 0.1,
                                   y: tile.size.height * 0.05,
                                   width: tile.size.width * 0.8,
                                   height: 14)
        progressBar.doubleValue = fraction

        tile.badgeLabel = String(activeCount)
        if tile.contentView !== tileView {
            tile.contentView = tileView
        }
        tile.display()

        lastDisplay = Date()
        lastFraction = fraction
        isVisible = true
    }

    private func hide() {
        guard isVisible else { return }

        let tile = NSApp.dockTile
        tile.contentView = nil
        tile.badgeLabel = nil
        tile.display()

        isVisible = false
        lastFraction = -1.0
        lastDisplay = .distantPast
    }
}
