// ===================================================================================================
// Copyright (C) 2017 Kaltura Inc.
//
// Licensed under the AGPLv3 license, unless a different license for a
// particular library is specified in the applicable library path.
//
// You may obtain a copy of the License at
// https://www.gnu.org/licenses/agpl-3.0.html
// ===================================================================================================

import PlayKit
import KalturaNetKit

/************************************************************/
// MARK: - KavaPlugin
/************************************************************/

@objc public class KavaPlugin: BasePlugin {
    
    // Kava event types
    enum KavaEventType : Int {
        /// Media was loaded
        case impression = 1
        /// Play was triggred
        case playRequest = 2
        /// Playing was triggred
        case play = 3
        /// Resume was triggred
        case resume = 4
        case playReached25Percent = 11
        case playReached50Percent = 12
        case playReached75Percent = 13
        case playReached100Percent = 14
        case pause = 33
        case replay = 34
        case seek = 35
        case captions = 38
        case sourceSelected = 39
        case error = 98
        case view = 99
    }
    
    var isMediaLoaded = false
    var isBuffering = false
    
    var seekPercent: Float = 0.0
    var targetSeekPosition: TimeInterval = 0
    
    var playReached25Percent = false
    var playReached50Percent = false
    var playReached75Percent = false
    var playReached100Percent = false
    var intervalOn = false
    var hasSeeked = false
    
    let deliveryTypeHls = "hls"
    let deliveryTypeOther = "url"
    var deliveryType = "url"
    
    var timer: Timer?
    var interval: TimeInterval = 10
    
    var selectedSource: PKMediaSource?
    /// The selected track indicated bitrate.
    var indicatedBitrate: Double?
    
    var errorCode: Int = -1
    
    var currentCaptionLanguage: String?
    
    var config: KavaPluginConfig!
    /// indicates whether we played for the first time or not.
    public var isFirstPlay: Bool = true
    /// indicates whether playback is paused.
    public var isPaused: Bool = true
    
    /************************************************************/
    // MARK: PKPlugin
    /************************************************************/
    
    public override class var pluginName: String {
        return "KavaPlugin"
    }
    
    public required init(player: Player, pluginConfig: Any?, messageBus: MessageBus) throws {
        try super.init(player: player, pluginConfig: pluginConfig, messageBus: messageBus)
        guard let config = pluginConfig as? KavaPluginConfig else {
            PKLog.error("missing plugin config or wrong plugin class type")
            throw PKPluginError.missingPluginConfig(pluginName: KavaPlugin.pluginName)
        }
        
        self.config = config
        self.registerEvents()
    }
    
    public override func onUpdateMedia(mediaConfig: MediaConfig) {
        super.onUpdateMedia(mediaConfig: mediaConfig)
        self.resetPlayerFlags()
        self.timer?.invalidate()
    }
    
    public override func onUpdateConfig(pluginConfig: Any) {
        super.onUpdateConfig(pluginConfig: pluginConfig)
        
        guard let config = pluginConfig as? KavaPluginConfig else {
            PKLog.error("plugin config is wrong")
            return
        }
        
        PKLog.debug("new config::\(String(describing: config))")
        self.config = config
    }
    
    public override func destroy() {
        self.messageBus?.removeObserver(self, events: playerEventsToRegister)
        
        if let t = self.timer {
            t.invalidate()
        }
        
        super.destroy()
    }
    
    func resetPlayerFlags() {
        self.isMediaLoaded = false
        self.isBuffering = false
        self.playReached25Percent = false
        self.playReached50Percent = false
        self.playReached75Percent = false
        self.playReached100Percent = false
        self.intervalOn = false
        self.hasSeeked = false
        self.isFirstPlay = true
        self.errorCode = -1
    }
    
    func createTimer() {
        if let t = self.timer {
            t.invalidate()
        }
        
        self.timer = Timer.every(self.interval) {
            guard let player = self.player else { return }
            let progress = Float(player.currentTime) / Float(player.duration)
            PKLog.debug("Progress is \(progress)")
            
            if progress >= 0.25 && !self.playReached25Percent && self.seekPercent <= 0.25 {
                self.playReached25Percent = true
                self.sendAnalyticsEvent(action: .playReached25Percent)
            } else if progress >= 0.5 && !self.playReached50Percent && self.seekPercent < 0.5 {
                self.playReached50Percent = true
                self.sendAnalyticsEvent(action: .playReached50Percent)
            } else if progress >= 0.75 && !self.playReached75Percent && self.seekPercent <= 0.75 {
                self.playReached75Percent = true
                self.sendAnalyticsEvent(action: .playReached75Percent)
            } else if progress >= 0.98 && !self.playReached100Percent && self.seekPercent < 1 {
                self.playReached100Percent = true
                self.sendAnalyticsEvent(action: .playReached100Percent)
            }
        }
    }
    
    func pauseTimer() {
        if let t = self.timer {
            t.invalidate()
        }
    }
    
    func sendAnalyticsEvent(action: KavaEventType) {
        guard let player = self.player else { return }
        PKLog.debug("Action: \(action)")
        
        // send event to messageBus
        let event = KavaEvent.Report(message: "send event with action type: \(action.rawValue)")
        self.messageBus?.post(event)
        
//        guard let builder: KalturaRequestBuilder = KavaService.get(config: self.config, eventType: <#T##Int#>, entryId: <#T##String#>, sessionId: <#T##String#>, eventIndex: <#T##Int#>, referrer: <#T##String#>, deliveryType: <#T##String#>, playbackType: <#T##String#>, position: <#T##TimeInterval#>, sessionStartTime: <#T##Float#>, bufferTime: <#T##Float#>, bufferTimeSum: <#T##Float#>, actualBitrate: <#T##Float#>, targetPosition: <#T##Float#>, caption: <#T##String#>, errorCode: <#T##Int#>)
        
//        guard let builder: KalturaRequestBuilder = KavaService.get(config: self.config,
//                                                                       eventType: action.rawValue,
//                                                                       entryId: PlayKitManager.clientTag,
//                                                                       duration: Float(player.duration),
//                                                                       sessionId: player.sessionId,
//                                                                       position: Int32(player.currentTime),
//                                                                       widgetId: "_\(self.config.partnerId)", isSeek: hasSeeked) else { return }
//        let builder: KalturaRequestBuilder! = nil
//        builder.set { (response: Response) in
//            PKLog.debug("Response: \(response)")
//        }
//        
//        USRExecutor.shared.send(request: builder.build())
    }
}

/************************************************************/
// MARK: - Extensions
/************************************************************/

extension PKEvent {
    /// Report Value, PKEvent Data Accessor
    @objc public var kavaMessage: String? {
        return self.data?[KavaEvent.messageKey] as? String
    }
}
