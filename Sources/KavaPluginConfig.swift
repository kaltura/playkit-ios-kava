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
    
    /// application ID.
    let applicationId = Bundle.main.bundleIdentifier
    /// The player id and configuration the content was played on.
    @objc public var uiconfId: Int
    /// The partner account ID on Kaltura's platform.
    @objc public var partnerId: Int
    /// The Kaltura encoded session data.
    @objc public var ks: String?
    /// The category id describing the current played context.
    @objc public var playbackContext: String?
    /// Received from plugin config if nothing there take app id wit relavant prefix.
    @objc public var referrer: String?
    
    @objc public var baseUrl: String
    @objc public var customVar1, customVar2, customVar3: String?
    
    /************************************************************/
    // MARK: - Initialization
    /************************************************************/
    
    @objc public init(uiconfId: Int, partnerId: Int, ks: String?, playbackContext: String?,
                      referrer: String?, customVar1: String?, customVar2: String?, customVar3: String?) {
        self.baseUrl = defaultBaseUrl
        self.uiconfId = uiconfId
        self.partnerId = partnerId
        self.ks = ks
        self.playbackContext = playbackContext
        self.customVar1 = customVar1
        self.customVar2 = customVar2
        self.customVar3 = customVar3
        super.init()
        
        if let referrerToBase64 = referrer {
            if self.isValidReferrer(referrerToBase64) {
                self.referrer = referrerToBase64.toBase64()
            }
        } else {
            PKLog.warning("Invalid referrer argument. Should start with app:// or http:// or https://")
            if let appId = applicationId {
                self.referrer = "app://" + appId
            } else {
                PKLog.warning("App id is not set")
            }   
        }
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
