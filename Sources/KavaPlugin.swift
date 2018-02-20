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
import SwiftyJSON

/************************************************************/
// MARK: - Playback Points Array
/************************************************************/

/// playbackPoints Array represents points in %, that show how much was reached from playback
let playbackPoints: [KavaPlugin.KavaEventType] = [KavaPlugin.KavaEventType.playReached25Percent, KavaPlugin.KavaEventType.playReached50Percent, KavaPlugin.KavaEventType.playReached75Percent, KavaPlugin.KavaEventType.playReached100Percent]

/************************************************************/
// MARK: - KavaPlugin
/************************************************************/

/// This class represents Kaltura real time analytics for live and on-demand video.
@objc public class KavaPlugin: BasePlugin {
    
    /// Kava event types
    enum KavaEventType : Int {
        /// Media was loaded
        case impression = 1
        /// Play event was triggred
        case playRequest = 2
        /// Playing event was triggred
        case play = 3
        /// Resume event was triggred
        case resume = 4
        /// player reached 25 percent
        case playReached25Percent = 11
        /// player reached 50 percent
        case playReached50Percent = 12
        /// player reached 75 percent
        case playReached75Percent = 13
        /// player reached 100 percent
        case playReached100Percent = 14
        /// Pause event was triggred
        case pause = 33
        /// Replay event was triggred
        case replay = 34
        /// Seeking event was triggred
        case seek = 35
        /// Captions event (text track was changed) was triggred
        case captions = 38
        /// Source Selected (media was changed) event was triggred
        case sourceSelected = 39
        /// Error event was triggred
        case error = 98
        /// Sent every 10 seconds of active playback.
        case view = 99
    }
    
    var config: KavaPluginConfig
    var sentPlaybackPoints: [KavaEventType : Bool] = KavaPlugin.cleanPlaybackPoints()
    var boundaryObservationToken: UUID?
    var viewTimer: Timer?
    var bufferingStartTime: Date?
    var kavaData = KavaPluginData()
    /// A sequence number which describe the order of events in a viewing session.
    private var eventIndex = 1
    
    /************************************************************/
    // MARK: PKPlugin
    /************************************************************/
    
    public override class var pluginName: String {
        return "kava"
    }
    
    public required init(player: Player, pluginConfig: Any?, messageBus: MessageBus, tokenReplacer: TokenReplacer?) throws {
        
        var _config: KavaPluginConfig?
        if let json = pluginConfig as? JSON {
            _config = KavaPluginConfig.parse(json: json)
        } else {
            _config = pluginConfig as? KavaPluginConfig
        }
        
        guard let config = _config else {
            PKLog.error("missing plugin config or wrong plugin class type")
            throw PKPluginError.missingPluginConfig(pluginName: KavaPlugin.pluginName).asNSError
        }
        
        self.config = config
        try super.init(player: player, pluginConfig: pluginConfig, messageBus: messageBus, tokenReplacer: tokenReplacer)
        self.registerEvents()
    }
    
    public static func merge(uiConf: Any, appConf: Any) -> Any? {
        var uiConfig: KavaPluginConfig?
        if uiConf is JSON {
            uiConfig = KavaPluginConfig.parse(json: uiConf as! JSON)
        } else {
            uiConfig = uiConf as? KavaPluginConfig
        }
        guard uiConfig != nil else { return appConf }
        
        var appConfig: KavaPluginConfig?
        if appConf is JSON {
            appConfig = KavaPluginConfig.parse(json: appConf as! JSON)
        } else {
            appConfig = appConf as? KavaPluginConfig
        }
        guard appConfig != nil else { return uiConfig }
        
        return uiConfig?.merge(config: appConfig!)
    }
    
    public override func onUpdateMedia(mediaConfig: MediaConfig) {
        PKLog.debug("onUpdateMedia: \(String(describing: mediaConfig))")
        super.onUpdateMedia(mediaConfig: mediaConfig)
        self.resetPlayerFlags()
        self.unregisterFromBoundaries()
        self.stopViewTimer()
        self.setMediaConfigParams()
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
        self.unregisterEvents()
        self.unregisterFromBoundaries()
        self.stopViewTimer()
        super.destroy()
    }
    
    static func cleanPlaybackPoints() -> [KavaEventType : Bool] {
        return playbackPoints.reduce([KavaEventType : Bool]()) { (dict, point) -> [KavaEventType : Bool] in
            var dict = dict
            dict[point] = false
            return dict
        }
    }
    
    func registerToBoundaries() {
        if let player = player, boundaryObservationToken == nil {
            let boundaryFactory = PKBoundaryFactory(duration: player.duration)
            let boundaries = playbackPoints.map({ boundaryFactory.percentageTimeBoundary(boundary: convertToPercentage(type: $0)) })
            boundaryObservationToken = player.addBoundaryObserver(boundaries: boundaries, observeOn: nil) { [weak self] (time, percentage) in
                self?.sendPercentageReachedEvent(percentage: Int(percentage * 100))
            }
        }
    }
    
    func unregisterFromBoundaries() {
        if let _ = boundaryObservationToken {
            player?.removeBoundaryObserver(boundaryObservationToken!)
            boundaryObservationToken = nil
        }
    }
    
    func setupViewTimer() {
        // If media is live don't setup view timer
        if let player = self.player {
            // see if is live via provider
            if player.isLive() {
                return
            // see if live via config
            } else if let isLive = config.isLive, isLive == true {
                return
            }
        }
        
        if viewTimer == nil {
            viewTimer = Timer.scheduledTimer(timeInterval: 10, target: self, selector: #selector(reportView), userInfo: nil, repeats: true)
        }
    }
    
    func stopViewTimer() {
        viewTimer?.invalidate()
        viewTimer = nil
    }
    
    @objc func reportView() {
        // If timer is nil, no reason to report.
        if self.viewTimer == nil {
            return
        }
        
        if let _ = bufferingStartTime {
            self.kavaData.totalBufferingInCurrentInterval += -bufferingStartTime!.timeIntervalSinceNow
            bufferingStartTime = Date()
        }
        
        self.sendAnalyticsEvent(event: .view, data: self.kavaData.totalBufferingInCurrentInterval)
        
        self.kavaData.totalBuffering += self.kavaData.totalBufferingInCurrentInterval
        self.kavaData.totalBufferingInCurrentInterval = TimeInterval()
    }
    
    func resetPlayerFlags() {
        self.kavaData.isMediaLoaded = false
        self.sentPlaybackPoints = KavaPlugin.cleanPlaybackPoints()
        self.kavaData.isFirstPlay = true
        self.kavaData.errorCode = -1
        self.bufferingStartTime = nil
        self.kavaData.totalBuffering = TimeInterval()
        self.kavaData.totalBufferingInCurrentInterval = TimeInterval()
        self.eventIndex = 1
    }
    
    func sendPercentageReachedEvent(percentage: Int) {
        var eventsToSend: [KavaEventType] = []
        for item in sentPlaybackPoints {
            if item.value == false && convertToPercentage(type: item.key) <= percentage {
                eventsToSend.append(item.key)
                sentPlaybackPoints[item.key] = true
            }
        }
        
        for item in eventsToSend.sorted(by: { (item1, item2) -> Bool in return item1.rawValue < item2.rawValue }) {
            sendAnalyticsEvent(event: item)
        }
    }
    
    func sendAnalyticsEvent(event: KavaEventType, data: Any? = nil) {
        guard let player = self.player else {
            PKLog.warning("Player/ MediaEntry is nil")
            
            return    
        }
        
        PKLog.debug("Action: \(event), data: \(data ?? "")")
        
        // send event to messageBus
        let eventType = KavaEvent.Report(message: "send event with action type: \(event.rawValue)")
        self.messageBus?.post(eventType)
        
        self.kavaData.mediaDuration = player.duration
        self.kavaData.mediaCurrentTime = player.currentTime
        
        guard let builder: KalturaRequestBuilder =
            KavaHelper.get(config: self.config,
                           eventType: event.rawValue,
                           eventIndex: self.eventIndex,
                           kavaData: self.kavaData,
                           player: player)
            else {
                PKLog.warning("KalturaRequestBuilder is nil")
                return
                
        }
        
        builder.set { (response: Response) in
            PKLog.debug("Response: \(String(describing: response))")
            
            if (self.config.sessionStartTime == nil) {
                self.config.sessionStartTime = response.data as? String
            }
        }
        
        USRExecutor.shared.send(request: builder.build())
        self.eventIndex+=1
    }
    
    /************************************************************/
    // MARK: - Private Functions
    /************************************************************/
    
    /// On media changed config internal params are set.
    private func setMediaConfigParams() {
        self.config.sessionId = self.player?.sessionId
        self.config.entryId = self.player?.mediaEntry?.id
        self.config.mediaFormat = self.player?.mediaFormat
        
        // If media is vod, set isLive param only once.
        if let player = self.player, !player.isLive() {
            self.config.isLive = player.isLive()
        }
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

extension KavaPlugin {
    func convertToPercentage(type: KavaEventType) -> Int {
        switch type {
        case .playReached25Percent:
            return 25
        case .playReached50Percent:
            return 50
        case .playReached75Percent:
            return 75
        case .playReached100Percent:
            return 100
        default:
            return 0
        }
    }
}
