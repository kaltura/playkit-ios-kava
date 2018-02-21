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
import SwiftyJSON

/************************************************************/
// MARK: KavaPluginConfig
/************************************************************/

@objc public class KavaPluginConfig: NSObject, PKPluginConfigMerge {
    
    /************************************************************/
    // MARK: - Enum
    /************************************************************/
    
    @objc public enum PlaybackType : Int {
        case unknown
        case live
        case vod
    }
    
    /************************************************************/
    // MARK: - Properties
    /************************************************************/
    
    private let defaultBaseUrl = "http://analytics.kaltura.com/api_v3/index.php"
    
    /// application ID.
    let applicationId = Bundle.main.bundleIdentifier
    /// The partner account ID on Kaltura's platform.
    @objc public var partnerId: Int
    /// The player id and configuration the content was played on.
    @objc public var uiconfId: Int
    /// The Kaltura encoded session data.
    @objc public var ks: String?
    /// The category id describing the current played context.
    @objc public var playbackContext: String?
    /// Received from plugin config if nothing there take app id wit relavant prefix.
    @objc public var referrer: String?
    /// Kaltura api base url
    @objc public var baseUrl: String
    /// Optional vars
    @objc public var customVar1, customVar2, customVar3: String?
    /// If not using providers user must mention playback type (live/ vod)
    /// Set by defualt to unknown
    @objc public var playbackType: PlaybackType = .unknown  
    /// DVR Threshold set by default to 2 minutes.
    @objc public var dvrThreshold = 120
    
    /************************************************************/
    // MARK: Internal Properties
    /************************************************************/
    
    var entryId: String?
    var sessionId: String?
    var sessionStartTime: String?
    var mediaFormat: PKMediaSource.MediaFormat?
    var isLive: Bool?
    var hasDVR: Bool?
    
    /************************************************************/
    // MARK: - Initialization
    /************************************************************/
    
    @objc public init(partnerId: Int, ks: String?, playbackContext: String?,
                      referrer: String?, customVar1: String?, customVar2: String?, customVar3: String?) {
        self.baseUrl = defaultBaseUrl
        // uiconfId is optional, set to -1 as default
        // can be overridden
        self.uiconfId = -1
        self.partnerId = partnerId
        self.ks = ks
        self.playbackContext = playbackContext
        self.customVar1 = customVar1
        self.customVar2 = customVar2
        self.customVar3 = customVar3
        super.init()
        
        if let referrerToBase64 = referrer {
            if self.isValidReferrer(referrerToBase64) {
                self.referrer = referrerToBase64
            }
        } else {
            PKLog.warning("Invalid referrer argument. Should start with app:// or http:// or https://")
            if let appId = applicationId {
                self.referrer = "app://" + appId
            } else {
                PKLog.warning("App id is not set")
            }   
        }
        
        // convert base64
        self.referrer = self.referrer?.toBase64()
    }
    
    public static func parse(json: JSON) -> KavaPluginConfig? {
        guard let jsonDictionary = json.dictionary else { return nil }
        
        guard let partnerId = jsonDictionary["partnerId"]?.int else { return nil }
        
        let config = KavaPluginConfig(partnerId: partnerId, ks: nil, playbackContext: nil, referrer: nil, customVar1: nil, customVar2: nil, customVar3: nil)
        
        if let baseUrl = jsonDictionary["baseUrl"]?.string, baseUrl != "" {
            config.baseUrl = baseUrl
        }
        if let uiconfId = jsonDictionary["uiconfId"]?.int {
            config.uiconfId = uiconfId
        }
        if let playbackContext = jsonDictionary["playbackContext"]?.string {
            config.playbackContext = playbackContext
        }
        if let referrer = jsonDictionary["referrer"]?.string {
            config.referrer = referrer
        }
        if let customVar1 = jsonDictionary["customVar1"]?.string {
            config.customVar1 = customVar1
        }
        if let customVar2 = jsonDictionary["customVar2"]?.string {
            config.customVar2 = customVar2
        }
        if let customVar3 = jsonDictionary["customVar3"]?.string {
            config.customVar3 = customVar3
        }
        
        return config
    }
    
    public func merge(config: PKPluginConfigMerge) -> PKPluginConfigMerge {
        if let config = config as? KavaPluginConfig {
            if config.baseUrl != defaultBaseUrl {
                baseUrl = config.baseUrl
            }
            if config.uiconfId != -1 {
                uiconfId = config.uiconfId
            }
            if let context = config.playbackContext {
                playbackContext = context
            }
            if let referrer = config.referrer {
                self.referrer = referrer
            }
            if let var1 = config.customVar1 {
                customVar1 = var1
            }
            if let var2 = config.customVar2 {
                customVar2 = var2
            }
            if let var3 = config.customVar3 {
                customVar3 = var3
            }
        }
        return self
    }
    
    /************************************************************/
    // MARK: Private Implementation
    /************************************************************/
    
    private func isValidReferrer(_ referrer: String) -> Bool {
        let validPrefixes = ["app://", "http://", "https://"]
        var isValid = false
        for p in validPrefixes {
            if referrer.hasPrefix(p) {
                isValid = true
                break
            }
        }
        return isValid
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
