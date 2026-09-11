//
//  WindowDelegate.swift
//  NPS Browser
//
//  Created by JK3Y on 5/12/18.
//  Copyright © 2018 JK3Y. All rights reserved.
//

protocol WindowDelegate {
    func getRegion() -> String
    
    func getItemType() -> ItemType

    func getSearchString() -> String


    func getDataController() -> DataViewController
    func getLoadingViewController() -> LoadingViewController
}
