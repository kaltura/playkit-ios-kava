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

internal class KavaService {
    
    static func get(config: KavaPluginConfig, entryId: String, sessionId: String, eventType: KavaPlugin.KavaEventType.RawValue, playbackType: String?, position: Double, eventIndex: Int,  sessionStartTime: String?, kavaData: KavaPluginData) -> KalturaRequestBuilder? {
        
        return self.get(
            config: config,
            baseURL: config.baseUrl,
            appId: config.applicationId!,
            uiconfId: config.uiconfId,
            partnerId: config.partnerId,
            ks: config.ks,
            playbackContext: config.playbackContext,
            // putting ! is safe since on KavaPluginConfig
            // on init func referrer gets value.
            referrer: config.referrer!,
            eventType: eventType,
            entryId: entryId,
            sessionId: sessionId,
            eventIndex: eventIndex,
            sessionStartTime: sessionStartTime,
            deliveryType: kavaData.deliveryType,
            playbackType: playbackType,
            clientVer: PlayKitManager.clientTag,
            clientTag: PlayKitManager.clientTag,
            position: position,
            bufferTime: kavaData.totalBufferingInCurrentInterval,
            bufferTimeSum: kavaData.totalBuffering,
            actualBitrate: kavaData.indicatedBitrate,
            targetPosition: kavaData.targetSeekPosition,
            caption: kavaData.currentCaptionLanguage,
            errorCode: kavaData.errorCode
        )
    }
    
    static func get(config: KavaPluginConfig, baseURL: String, appId: String, uiconfId: Int, partnerId: Int, ks: String?, playbackContext: String?, referrer: String, eventType: Int, entryId: String, sessionId: String, eventIndex: Int, sessionStartTime: String?, deliveryType: String, playbackType: String?, clientVer: String, clientTag: String, position: TimeInterval, bufferTime: Double, bufferTimeSum: Double, actualBitrate: Double?, targetPosition: Double, caption: String?, errorCode: Int) -> KalturaRequestBuilder? {
        
        if let request: KalturaRequestBuilder = KalturaRequestBuilder(url: baseURL, service: nil, action: nil) {
            request
            .setParam(key: "eventType", value: String(eventType))
            .setParam(key: "partnerId", value: String(partnerId))
            .setParam(key: "entryId", value: entryId)
            .setParam(key: "sessionId", value: sessionId)
            .setParam(key: "eventIndex", value: String(eventIndex))
            .setParam(key: "referrer", value: referrer)
            .setParam(key: "deliveryType", value: deliveryType)
            .setParam(key: "clientVer", value: "kwidget:v\(clientVer)")
            .setParam(key: "clientTag", value: "kwidget:v\(clientVer)")
            .setParam(key: "position", value: String(position))
            
            if let mediaType = playbackType {
                request.setParam(key: "playbackType", value: mediaType)
            } else {
                switch config.playbackType {
                case KavaPluginConfig.PlaybackType.unknown:
                    fatalError("media type on KavaPluginConfig is not set when providers are not used.")
                case KavaPluginConfig.PlaybackType.live:
                    request.setParam(key: "playbackType", value: "live")
                case KavaPluginConfig.PlaybackType.vod:
                    request.setParam(key: "playbackType", value: "vod")
                }
            }
            
            if let sessionTime = sessionStartTime {
                request.setParam(key: "sessionStartTime", value: sessionTime)
            }
            
            switch eventType {
            case KavaPlugin.KavaEventType.view.rawValue,
                 KavaPlugin.KavaEventType.play.rawValue,
                 KavaPlugin.KavaEventType.resume.rawValue:
                request.setParam(key: "bufferTime", value: String(bufferTime))
                request.setParam(key: "bufferTimeSum", value: String(bufferTimeSum))
                request.setParam(key: "actualBitrate", value: String(describing: actualBitrate))
            case KavaPlugin.KavaEventType.seek.rawValue:
                request.setParam(key: "targetPosition", value: String(targetPosition))
            case KavaPlugin.KavaEventType.captions.rawValue:
                if let currentCaption = caption {
                    request.setParam(key: "caption", value: currentCaption)
                }
            case KavaPlugin.KavaEventType.error.rawValue:
                if (errorCode != -1) {
                    request.setParam(key: "errorCode", value: String(errorCode))
                }
            default:
                PKLog.debug("KavaEventType accured: \(eventType)")
            }
            
            KavaService.addOptionalParams(config: config, request: request)

            request.set(responseSerializer: StringSerializer())
            
            return request
        } else {
            PKLog.error("KalturaRequestBuilder failed")
            return nil
        }
    }
    
    static private func addOptionalParams(config: KavaPluginConfig, request: KalturaRequestBuilder) {
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

