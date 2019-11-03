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
    
    static func builder(config: KavaPluginConfig,
                        mediaType: MediaType,
                        eventType: KavaPlugin.EventType,
                        eventIndex: Int,
                        kavaData: KavaPluginData,
                        player: Player) -> KalturaRequestBuilder? {
        
        if let request: KalturaRequestBuilder = KalturaRequestBuilder(url: config.baseUrl, service: nil, action: nil) {
            
            request
                .setParam(key: "eventType", value: String(describing: eventType.rawValue))
                .setParam(key: "eventIndex", value: String(eventIndex))
                .setParam(key: "deliveryType", value: kavaData.deliveryType)
            
            addMediaParams(config: config,
                           player: player,
                           request: request)
            
            addMediaTypeParam(config: config,
                              mediaType: mediaType,
                              kavaData: kavaData,
                              request: request,
                              player: player)
            
            addDynamicParams(eventType: eventType,
                             kavaData: kavaData,
                             request: request)
            
            addOptionalParams(config: config,
                              request: request)
            
            // Response can be Json format or the old String format
            request.set(responseSerializer: KavaSerializer())
            
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
                                       player: Player,
                                       request: KalturaRequestBuilder) {
        request.setParam(key: "service", value: "analytics")
        request.setParam(key: "action", value: "trackEvent")
        request.setParam(key: "partnerId", value: String(config.partnerId))
        // putting ! is safe since on KavaPluginConfig
        // on init func referrer gets value.
        request.setParam(key: "referrer", value: config.referrer!)
        request.setParam(key: "clientVer", value: "\(PlayKitManager.clientTag)")
        if let bundleId = Bundle.main.bundleIdentifier {
            request.setParam(key: "application", value: "\(bundleId)")
        }
        request.setParam(key: "sessionId", value: player.sessionId)
        
        if let entryId = player.mediaEntry?.id {
            request.setParam(key: "entryId", value: entryId)
        }
        
        if let sessionStartTime = config.sessionStartTime {
            request.setParam(key: "sessionStartTime", value: sessionStartTime)
        }
        
        if let userId = config.userId {
            request.setParam(key: "userId", value: userId)
        }
    }
    
    /// Adds params that are changed during playback.
    static private func addDynamicParams(eventType: KavaPlugin.EventType,
                                         kavaData: KavaPluginData,
                                         request: KalturaRequestBuilder) {
        func kibibits(bits: Double) -> Double {
            return bits / 1024
        }
        
        if let currentTime = kavaData.mediaCurrentTime {
            request.setParam(key: "position", value: String(currentTime))
        }
        
        switch eventType {
        case KavaPlugin.EventType.view, KavaPlugin.EventType.play, KavaPlugin.EventType.resume:
            request.setParam(key: "bufferTime", value: String(kavaData.totalBufferingInCurrentInterval))
            request.setParam(key: "bufferTimeSum", value: String(kavaData.totalBuffering))
            request.setParam(key: "actualBitrate", value: String(describing: kibibits(bits: kavaData.indicatedBitrate)))
            // view event has more data to be set
            if eventType == KavaPlugin.EventType.view {
                request.setParam(key: "averageBitrate", value: String(kibibits(bits: kavaData.bitrateSum / Double(kavaData.bitrateCount))))
                request.setParam(key: "playTimeSum", value: String(kavaData.totalPlayTime))
                if let currentAudioLanguage = kavaData.currentAudioLanguage {
                    request.setParam(key: "audioLanguage", value: currentAudioLanguage)
                }
                if let currentCaptionLanguage = kavaData.currentCaptionLanguage {
                    request.setParam(key: "captionsLanguage", value: currentCaptionLanguage)
                }
            }
            if eventType == KavaPlugin.EventType.play {
                if let joinTime = kavaData.joinTime {
                    request.setParam(key: "joinTime", value: String(joinTime))
                }
            }
            
        case KavaPlugin.EventType.seek:
            request.setParam(key: "targetPosition", value: String(kavaData.targetSeekPosition))
            
        case KavaPlugin.EventType.captions:
            if let caption = kavaData.currentCaptionLanguage {
                request.setParam(key: "caption", value: caption)
            }
            
        case KavaPlugin.EventType.audioSelected:
            if let audioLanguage = kavaData.currentAudioLanguage {
                request.setParam(key: "language", value: audioLanguage)
            }
            
        case KavaPlugin.EventType.error:
            if (kavaData.errorCode != -1) {
                request.setParam(key: "errorCode", value: String(kavaData.errorCode))
                request.setParam(key: "errorDetails", value: kavaData.errorDetails ?? "")
            }
            
        case KavaPlugin.EventType.flavorSwitched:
            request.setParam(key: "actualBitrate", value: String(describing: kibibits(bits: kavaData.indicatedBitrate)))
            
        default:
            PKLog.debug("KavaEventType occurred: \(eventType) (\(eventType.rawValue)), without adding Dynamic Params")
        }
    }
    
    static func isLiveMedia(mediaType: MediaType, config: KavaPluginConfig, player: Player) -> Bool {
        
        // For the most reliable result, check the declared media type
        if mediaType == .live || mediaType == .dvrLive {
            return true
        } else if mediaType == .vod {
            return false
        }
        
        // MediaType is not set, try the config object
        if config.playbackType == .live {
            return true
        } else if config.playbackType == .vod {
            return false
        }
        
        // Not in config -- ask the player
        return player.isLive()
    }
    
    static private func addMediaTypeParam(config: KavaPluginConfig,
                                          mediaType: MediaType,
                                          kavaData: KavaPluginData,
                                          request: KalturaRequestBuilder,
                                          player: Player) {
        
        if isLiveMedia(mediaType: mediaType, config: config, player: player) {
            handleLive(kavaData: kavaData, config: config, request: request)
        } else {
            handleVod(request: request)
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
            if KavaPluginData.inDVRState(duration: duration, currentTime: currentTime, dvrThreshold: config.dvrThreshold) {
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
        
        if let applicationVersion = config.applicationVersion {
            request.setParam(key: "applicationVer", value: applicationVersion)
        }
        
        if let playlistId = config.playlistId {
            request.setParam(key: "playlistId", value: playlistId)
        }
    }
}
