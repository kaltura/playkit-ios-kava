// ===================================================================================================
// Copyright (C) 2017 Kaltura Inc.
//
// Licensed under the AGPLv3 license, unless a different license for a
// particular library is specified in the applicable library path.
//
// You may obtain a copy of the License at
// https://www.gnu.org/licenses/agpl-3.0.html
// ===================================================================================================

import UIKit
import SwiftyJSON
import PlayKit
import KalturaNetKit

class KavaHelper {
    static func get(config: KavaPluginConfig,
                    eventType: KavaPlugin.KavaEventType.RawValue,
                    eventIndex: Int,
                    kavaData: KavaPluginData,
                    player: Player) -> KalturaRequestBuilder? {
        
        if let request: KalturaRequestBuilder = KalturaRequestBuilder(url: config.baseUrl, service: nil, action: nil) {
            
            addMediaParams(config: config,
                           request: request)
            
            request
                .setParam(key: "eventType", value: String(eventType))
                .setParam(key: "eventIndex", value: String(eventIndex))
                .setParam(key: "deliveryType", value: kavaData.deliveryType)
            
            addMediaTypeParam(config: config,
                              kavaData: kavaData,
                              request: request,
                              player: player)
            addDynamicParams(eventType: eventType,
                             kavaData: kavaData,
                             request: request)
            addOptionalParams(config: config,
                              request: request)
            
            // Response in this case is not in Json format
            // It's set to StringSerializer otherwise respone is errored.
            request.set(responseSerializer: StringSerializer())
            
            return request
        } else {
            PKLog.error("KalturaRequestBuilder failed")
            
            return nil
        }
    }
    
    /************************************************************/
    // MARK: Private Implementation
    /************************************************************/
    
    /// Adds media params that won't be changed until media is updated.
    static private func addMediaParams(config: KavaPluginConfig,
                                       request: KalturaRequestBuilder) {
        request.setParam(key: "service", value: "analytics")
        request.setParam(key: "action", value: "trackEvent")
        request.setParam(key: "partnerId", value: String(config.partnerId))
        // putting ! is safe since on KavaPluginConfig
        // on init func referrer gets value.
        request.setParam(key: "referrer", value: config.referrer!)
        request.setParam(key: "clientVer", value: "kwidget:v\(PlayKitManager.clientTag)")
        request.setParam(key: "clientTag", value: "kwidget:v\(PlayKitManager.clientTag)")
        
        if let entryId = config.entryId {
            request.setParam(key: "entryId", value: entryId)
        }
        
        if let sessionId = config.sessionId {
            request.setParam(key: "sessionId", value: sessionId)
        }
        
        if let sessionStartTime = config.sessionStartTime {
            request.setParam(key: "sessionStartTime", value: sessionStartTime)
        }
    }
    
    /// Adds params that are changed during playback.
    static private func addDynamicParams(eventType: Int,
                                         kavaData: KavaPluginData,
                                         request: KalturaRequestBuilder) {
        
        if let currentTime = kavaData.mediaCurrentTime {
            request.setParam(key: "position", value: String(currentTime))
        }
        
        switch eventType {
        case KavaPlugin.KavaEventType.view.rawValue,
             KavaPlugin.KavaEventType.play.rawValue,
             KavaPlugin.KavaEventType.resume.rawValue:
            request.setParam(key: "bufferTime", value: String(kavaData.totalBufferingInCurrentInterval))
            request.setParam(key: "bufferTimeSum", value: String(kavaData.totalBuffering))
            request.setParam(key: "actualBitrate", value: String(describing: kavaData.indicatedBitrate))
        case KavaPlugin.KavaEventType.seek.rawValue:
            request.setParam(key: "targetPosition", value: String(kavaData.targetSeekPosition))
        case KavaPlugin.KavaEventType.captions.rawValue:
            if let caption = kavaData.currentCaptionLanguage {
                request.setParam(key: "caption", value: caption)
            }
        case KavaPlugin.KavaEventType.error.rawValue:
            if (kavaData.errorCode != -1) {
                request.setParam(key: "errorCode", value: String(kavaData.errorCode))
            }
        default:
            PKLog.debug("KavaEventType accured: \(eventType)")
        }
    }
    
    static private func addMediaTypeParam(config: KavaPluginConfig,
                                          kavaData: KavaPluginData,
                                          request: KalturaRequestBuilder,
                                          player: Player) {
        // Media type is known from  media provider
        if config.isLive != nil {
            // Media is VOD
            handleVod(request: request)
        } else if player.isLive() {
            // Media is Live
            handleLive(kavaData: kavaData,
                       config: config,
                       request: request)
        }
        // When not using providers/ media type is not known
        // Get it from config
        else {
            switch config.playbackType {
            case KavaPluginConfig.PlaybackType.unknown:
                // should be asserted when PlaybackType is not set
                assertionFailure("media type on KavaPluginConfig is not set when providers are not used.")
            case KavaPluginConfig.PlaybackType.live:
                handleLive(kavaData: kavaData, config: config, request: request)
            case KavaPluginConfig.PlaybackType.vod:
                handleVod(request: request)
            }
        }
    }
    
    static private func handleVod(request: KalturaRequestBuilder) {
        request.setParam(key: "playbackType", value: "vod")
    }
    
    static private func handleLive(kavaData: KavaPluginData,
                                   config: KavaPluginConfig,
                                   request: KalturaRequestBuilder) {
        if let duration = kavaData.mediaDuration,
            let currentTime = kavaData.mediaCurrentTime {
            if KavaPluginData.hasDVR(duration: duration,
                                     currentTime: currentTime,
                                     dvrThreshold: config.dvrThreshold) {
                request.setParam(key: "playbackType", value: "dvr")
            } else {
                request.setParam(key: "playbackType", value: "live")
            }
        }
    }
    
    /// Adds optional params.
    static private func addOptionalParams(config: KavaPluginConfig,
                                          request: KalturaRequestBuilder) {
        if let context = config.playbackContext {
            request.setParam(key: "playbackContext", value: context)
        }
        
        if let customVar1 = config.customVar1 {
            request.setParam(key: "customVar1", value: customVar1)
        }
        
        if let customVar2 = config.customVar2 {
            request.setParam(key: "customVar2", value: customVar2)
        }
        
        if let customVar3 = config.customVar3 {
            request.setParam(key: "customVar3", value: customVar3)
        }
        
        if let ks = config.ks {
            request.setParam(key: "ks", value: ks)
        }
        
        if config.uiconfId != -1 {
            request.setParam(key: "uiConfId", value: String(config.uiconfId))
        }
    }
}
