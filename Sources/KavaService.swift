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
    
    static func get(config: KavaPluginConfig, entryId: String, sessionId: String, eventType: KavaPlugin.KavaEventType.RawValue, playbackType: String, position: Double, eventIndex: Int, kavaData: KavaPluginData) -> KalturaRequestBuilder? {
        
        return self.get(
            baseURL: config.baseUrl,
            appId: config.applicationId!,
            uiconfId: config.uiconfId,
            partnerId: config.partnerId,
            ks: config.ks,
            playbackContext: config.playbackContext,
            referrer: config.referrer,
            eventType: eventType,
            entryId: entryId,
            sessionId: sessionId,
            eventIndex: eventIndex,
            deliveryType: kavaData.deliveryType,
            // TODO:: optimizie to genral case
            playbackType: playbackType,
            clientVer: PlayKitManager.clientTag,
            clientTag: PlayKitManager.clientTag,
            position: position,
            // TODO::
            sessionStartTime: 0,//kavaData.sessionStartTime,
            bufferTime: kavaData.totalBufferingInCurrentInterval,
            bufferTimeSum: kavaData.totalBuffering,
            actualBitrate: kavaData.indicatedBitrate!,
            targetPosition: kavaData.targetSeekPosition,
            caption: kavaData.currentCaptionLanguage!,
            errorCode: kavaData.errorCode
        )
    }
    
    // TODO:: add optional params to requset
    
    // TODO:: finilize request
    static func get(baseURL: String, appId: String, uiconfId: Int, partnerId: Int, ks: String?, playbackContext: String?, referrer: String?, eventType: Int, entryId: String, sessionId: String,   eventIndex: Int, deliveryType: String, playbackType: String, clientVer: String, clientTag: String, position: TimeInterval, sessionStartTime: Double, bufferTime: Double, bufferTimeSum: Double, actualBitrate: Double, targetPosition: Double, caption: String, errorCode: Int) -> KalturaRequestBuilder? {
        
        if let request: KalturaRequestBuilder = KalturaRequestBuilder(url: baseURL, service: nil, action: nil) {
            request
                .setParam(key: "clientTag", value: "kwidget:v\(clientVer)")
//                .setParam(key: "service", value: "stats")
//                .setParam(key: "apiVersion", value: "3.1")
//                .setParam(key: "expiry", value: "86400")
//                .setParam(key: "format", value: "1")
//                .setParam(key: "ignoreNull", value: "1")
//                .setParam(key: "action", value: "collect")
//                .setParam(key: "event:eventType", value: "\(eventType)")
//                .setParam(key: "event:clientVer", value: "\(clientVer)")
//                .setParam(key: "event:currentPoint", value: "\(position)")
//                .setParam(key: "event:duration", value: "\(duration)")
//                .setParam(key: "event:eventTimeStamp", value: "\(Date().timeIntervalSince1970)")
//                .setParam(key: "event:isFirstInSession", value: "false")
//                .setParam(key: "event:objectType", value: "KalturaStatsEvent")
//                .setParam(key: "event:partnerId", value: partnerId)
//                .setParam(key: "event:sessionId", value: sessionId)
//                .setParam(key: "event:uiconfId", value: "\(uiConfId)")
//                .setParam(key: "event:seek", value: String(isSeek))
//                .setParam(key: "event:entryId", value: entryId)
//                .setParam(key: "event:widgetId", value: widgetId)
//                .setParam(key: "event:referrer", value: referrer)
//                .set(method: .get)
//
//            if contextId > 0 {
//                request.setParam(key: "event:contextId", value: "\(contextId)")
//            }
//            if let applicationId = appId, applicationId != "" {
//                request.setParam(key: "event:applicationId", value: applicationId)
//            }
//            if let userId = userId, userId != "" {
//                request.setParam(key: "event:userId", value: userId)
//            }
            
            return request
        } else {
            return nil
        }
    }
}

