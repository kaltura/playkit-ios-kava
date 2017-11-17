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
    
    static func get(config: KavaPluginConfig, entryId: String, sessionId: String, eventType: KavaPlugin.KavaEventType.RawValue, playbackType: String, position: Double, eventIndex: Int,  sessionStartTime: String?, kavaData: KavaPluginData) -> KalturaRequestBuilder? {
        
        return self.get(
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
            // TODO:: optimizie to genral case
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
    
    // TODO:: add optional params to requset
    
    // TODO:: finilize request
    static func get(baseURL: String, appId: String, uiconfId: Int, partnerId: Int, ks: String?, playbackContext: String?, referrer: String, eventType: Int, entryId: String, sessionId: String, eventIndex: Int, sessionStartTime: String?, deliveryType: String, playbackType: String, clientVer: String, clientTag: String, position: TimeInterval, bufferTime: Double, bufferTimeSum: Double, actualBitrate: Double?, targetPosition: Double, caption: String?, errorCode: Int) -> KalturaRequestBuilder? {
        
        if let request: KalturaRequestBuilder = KalturaRequestBuilder(url: baseURL, service: nil, action: nil) {
            request
            .setParam(key: "eventType", value: String(eventType))
            .setParam(key: "partnerId", value: String(partnerId))
            .setParam(key: "entryId", value: entryId)
            .setParam(key: "sessionId", value: sessionId)
            .setParam(key: "eventIndex", value: String(eventIndex))
            .setParam(key: "referrer", value: referrer)
            .setParam(key: "deliveryType", value: deliveryType)
            .setParam(key: "playbackType", value: playbackType)
            .setParam(key: "clientVer", value: "kwidget:v\(clientVer)")
            .setParam(key: "clientTag", value: "kwidget:v\(clientVer)")
            .setParam(key: "position", value: String(position))
            
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

            request.set(responseSerializer: StringSerializer())

            return request
        } else {
            return nil
        }
    }
}

