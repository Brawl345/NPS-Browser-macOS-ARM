# NPS Browser for macOS on ARM.

A Swift 5 implementation of NPS Browser.\
**Tested and working on macOS 14.7.7**

Additionally, this fork fixes the download & bookmarks panels and ships native arm64 binaries for pkg2zip and vitanpupdatelinks.

![](/Screenshots/main.png?raw=true)

## Features
* Separate Download and Extraction Folders
* Localization in Simplified Chinese
* Bookmarks can be saved by clicking the star icon in the corner of the details panel
* Downloads can be started from the bookmark list
* Downloads can be stopped and resumed at any point, they can also be resumed if the app is closed during download
* Compatibility pack support for FW 3.61+
* Game updates are always the latest version
* Game artwork is displayed

## Usage
* Change or set URLs and extraction preferences in the Preferences window
* From the menu select Database > Reload or press ⌘R
* Compatibility pack URLs must be the raw text file.

## Removal
After moving to trash, run:
```
rm -r ~/Library/Application\ Support/JK3Y.NPS-Browser/
rm -r ~/Library/Caches/JK3Y.NPS-Browser
rm -r ~/Library/Caches/NPS\ Browser
defaults delete JK3Y.NPS-Browser
```

#### [Changelog](https://github.com/Brawl345/NPS-Browser-macOS-ARM/blob/master/CHANGELOG.md)

## Thanks
* Ann0ying for app icon
* davidroman0O and mmozeiko for the pkg2zip PRs that I integrated [here](https://github.com/Brawl345/pkg2zip)
* devnoname120 for [vitanpupdatelinks](https://github.com/Brawl345/vitanpupdatelinks)
* L1cardo for Simplified Chinese translation
* mavethee for Polish translation
* danieltarazona for Swift 5 update and Carthage remove

