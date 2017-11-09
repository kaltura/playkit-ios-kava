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

let playbackPoints: [KavaPlugin.KavaEventType] = [KavaPlugin.KavaEventType.playReached25Percent, KavaPlugin.KavaEventType.playReached50Percent, KavaPlugin.KavaEventType.playReached75Percent, KavaPlugin.KavaEventType.playReached100Percent]

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
    var targetSeekPosition: TimeInterval = 0

    var sentPlaybackPoints: [KavaEventType : Bool] = cleanPlaybackPoints()
    var boundaryObservationToken: UUID?
    var viewTimer: Timer?
    
    var totalBuffering: TimeInterval = TimeInterval()
    var totalBufferingInCurrentInterval: TimeInterval = TimeInterval()
    var bufferingStartTime: Date?
    
    let deliveryTypeHls = "hls"
    let deliveryTypeOther = "url"
    var deliveryType = "url"
    
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
        self.unregisterFromBoundaries()
        self.stopViewTimer()
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
        if viewTimer == nil {
            viewTimer = Timer.scheduledTimer(timeInterval: 10, target: self, selector: #selector(reportView), userInfo: nil, repeats: true)
        }
    }
    
    func stopViewTimer() {
        viewTimer?.invalidate()
        viewTimer = nil
    }
    
    @objc func reportView() {
        if let _ = bufferingStartTime {
            totalBufferingInCurrentInterval += -bufferingStartTime!.timeIntervalSinceNow
            bufferingStartTime = Date()
        }
        sendAnalyticsEvent(action: .view, data: totalBufferingInCurrentInterval)
        
        totalBuffering += totalBufferingInCurrentInterval
        totalBufferingInCurrentInterval = TimeInterval()
    }
    
    func resetPlayerFlags() {
        self.isMediaLoaded = false
        self.sentPlaybackPoints = KavaPlugin.cleanPlaybackPoints()
        self.isFirstPlay = true
        self.errorCode = -1
        self.bufferingStartTime = nil
        self.totalBuffering = TimeInterval()
        self.totalBufferingInCurrentInterval = TimeInterval()
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
            sendAnalyticsEvent(action: item)
        }
    }
    
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
    
    func sendAnalyticsEvent(action: KavaEventType, data: Any? = nil) {
        //guard let player = self.player else { return }
        PKLog.debug("Action: \(action), data: \(data ?? "")")
        
        // send event to messageBus
        //let event = KavaEvent.Report(message: "send event with action type: \(action.rawValue)")
        //self.messageBus?.post(event)
        
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
