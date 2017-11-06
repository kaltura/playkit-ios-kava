// ===================================================================================================
// Copyright (C) 2017 Kaltura Inc.
//
// Licensed under the AGPLv3 license, unless a different license for a
// particular library is specified in the applicable library path.
//
// You may obtain a copy of the License at
// https://www.gnu.org/licenses/agpl-3.0.html
// ===================================================================================================

import Foundation
import PlayKit

/************************************************************/
// MARK: KavaPluginConfig
/************************************************************/

@objc public class KavaPluginConfig: NSObject {
    /************************************************************/
    // MARK: - Properties
    /************************************************************/
    
    private let defaultBaseUrl = "http://analytics.kaltura.com/api_v3/index.php"
    
    let applicationId = Bundle.main.bundleIdentifier
    
    @objc public var uiconfId: Int
    @objc public var partnerId: Int
    @objc public var ks: String
    @objc public var playbackContext: String
    @objc public var referrerAsBase64: String? {
        get { return self.referrerAsBase64 }
        set {
            if let referrer = newValue {
                if self.isValidReferrer(referrer) {
                    self.referrerAsBase64 = referrer.toBase64()
                } else {
                    PKLog.warning("Invalid referrer argument. Should start with app:// or http:// or https://")
                    self.referrerAsBase64 = nil
                }
            }
        }
    }
    
    @objc public var baseUrl: String
    @objc public var customVar1, customVar2, customVar3: String?
    
    /************************************************************/
    // MARK: - Initialization
    /************************************************************/
    
    @objc public init(uiconfId: Int, partnerId: Int, ks: String, playbackContext: String,
                      referrerAsBase64: String, baseUrl: String, customVar1: String, customVar2: String, customVar3: String) {
        self.baseUrl = defaultBaseUrl
        self.uiconfId = uiconfId
        self.partnerId = partnerId
        self.ks = ks
        self.playbackContext = playbackContext
        self.customVar1 = customVar1
        self.customVar2 = customVar2
        self.customVar3 = customVar3
        super.init()
        self.referrerAsBase64 = referrerAsBase64
    }
    
    /************************************************************/
    // MARK: Private Implementation
    /************************************************************/
    
    private func isValidReferrer(_ referrer: String) -> Bool {
        let validPrefixes = ["app://", "http://", "https://"]
        return validPrefixes.contains(referrer)
    }
}

/************************************************************/
// MARK: - Extensions
/************************************************************/

extension String {
    func toBase64() -> String {
        return Data(self.utf8).base64EncodedString()
    }
}
