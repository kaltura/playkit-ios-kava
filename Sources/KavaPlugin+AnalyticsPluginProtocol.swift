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

extension KavaPlugin: AnalyticsPluginProtocol {
    
    /************************************************************/
    // MARK: - AnalyticsPluginProtocol
    /************************************************************/
    
    public var isFirstPlay: Bool {
        get {
            return self.kavaData.isFirstPlay
        }
        set(newValue) {
            self.kavaData.isFirstPlay = newValue
        }
    }
    
    public var playerEventsToRegister: [PlayerEvent.Type] {
        return [
            PlayerEvent.stateChanged,
            PlayerEvent.loadedMetadata,
            PlayerEvent.play,
            PlayerEvent.pause,
            PlayerEvent.playing,
            PlayerEvent.seeking,
            PlayerEvent.sourceSelected,
            PlayerEvent.ended,
            PlayerEvent.playbackInfo,
            PlayerEvent.textTrackChanged,
            PlayerEvent.videoTrackChanged,
            PlayerEvent.error
        ]
    }
    
    public func registerEvents() {
        self.playerEventsToRegister.forEach { playerEvent in
            PKLog.debug("Register event: \(playerEvent.self)")
            
            self.messageBus?.addObserver(self, events: [playerEvent], block: { [weak self] event in
                guard let strongSelf = self else { return }
                
                switch playerEvent {
                case let e where e.self == PlayerEvent.stateChanged:
                    strongSelf.handleStateChanged(event: event)
                case let e where e.self == PlayerEvent.loadedMetadata:
                    strongSelf.handleLoadedMetadata()
                case let e where e.self == PlayerEvent.play:
                    strongSelf.handlePlay()
                case let e where e.self == PlayerEvent.pause:
                    strongSelf.handlePause()
                case let e where e.self == PlayerEvent.playing:
                    strongSelf.handlePlaying()
                case let e where e.self == PlayerEvent.seeking:
                    strongSelf.handleSeeking(targetSeekPosition: event.targetSeekPosition)
                case let e where e.self == PlayerEvent.sourceSelected:
                    strongSelf.handleSourceSelected(mediaSource: event.mediaSource)
                case let e where e.self == PlayerEvent.ended:
                    strongSelf.handleEnded()
                case let e where e.self == PlayerEvent.videoTrackChanged:
                    strongSelf.handleVideoTrackChanged(videoTrack: event.bitrate)
                case let e where e.self == PlayerEvent.textTrackChanged:
                    strongSelf.handleTextTrackChanged(textTrack: event.selectedTrack)
                case let e where e.self == PlayerEvent.error:
                    strongSelf.handleError(error: event.error)
                default: assertionFailure("all events must be handled")
                }
                
            })
            
            self.messageBus?.addObserver(self, events: [AdEvent.error], block: { [weak self] (event) in
                guard let strongSelf = self else { return }
                strongSelf.handleError(error: event.error)
            })
        }
    }
    
    public func unregisterEvents() {
        self.messageBus?.removeObserver(self, events: playerEventsToRegister)
        self.messageBus?.removeObserver(self, events: [AdEvent.error])
    }
    
    /************************************************************/
    // MARK: Private Implementation
    /************************************************************/
    
    private func handleStateChanged(event: PKEvent) {
        PKLog.debug("state changed event: \(event)")
        
        switch event.newState {
        case .ready:
            PKLog.info("media ready")
            
            if let _ = bufferingStartTime {
                self.kavaData.totalBufferingInCurrentInterval += -bufferingStartTime!.timeIntervalSinceNow
                bufferingStartTime = nil
            }
            
            self.sendMediaLoaded()
            self.registerToBoundaries()
        case .buffering:
            bufferingStartTime = Date()
        default: break
        }
    }
    
    private func handleLoadedMetadata() {
        PKLog.debug("loadedMetadata event")
        
        self.kavaData.playbackType = self.getPlaybackType()
        self.sendMediaLoaded()
    }
    
    private func handlePlay() {
        PKLog.debug("play event")
        
        self.sendAnalyticsEvent(event: KavaEventType.playRequest)
        
        if self.sentPlaybackPoints[KavaEventType.playReached100Percent] == true {
            self.sendAnalyticsEvent(event: KavaEventType.replay)
        }
    }
    
    private func handlePause() {
        PKLog.debug("pause event")
        
        self.kavaData.isPaused = true
        self.sendAnalyticsEvent(event: KavaEventType.pause)
        self.reportView()
        self.stopViewTimer()
    }
    
    private func handlePlaying() {
        PKLog.debug("playing event")
        
        if self.isFirstPlay {
            self.isFirstPlay = false
            self.sendAnalyticsEvent(event: KavaEventType.play)
        } else if self.kavaData.isPaused {
            self.sendAnalyticsEvent(event: KavaEventType.resume)
        }
        
        self.kavaData.isPaused = false
        self.setupViewTimer()
    }
    
    private func handleSeeking(targetSeekPosition: NSNumber?) {
        PKLog.debug("seeking event")
        
        if let seekPosition = targetSeekPosition {
            self.kavaData.targetSeekPosition = Double(truncating: seekPosition)
        }
        
        self.sendAnalyticsEvent(event: KavaEventType.seek)
    }
    
    private func handleSourceSelected(mediaSource: PKMediaSource?) {
        PKLog.debug("sourceSelected event")
        
        if let source = mediaSource {
            self.kavaData.selectedSource = source
            self.updateDeliveryType(mediaFormat: source.mediaFormat)
        }
    }
    
    private func handleEnded() {
        PKLog.debug("ended event")
        
        self.sendPercentageReachedEvent(percentage: 100)
        self.reportView()
        self.stopViewTimer()
    }
    
    private func handleVideoTrackChanged(videoTrack: NSNumber?) {
        PKLog.debug("videoTrackChanged event")
        
        if let bitrate = videoTrack {
            self.kavaData.indicatedBitrate = Double(truncating: bitrate)
        }
    }
    
    private func handleTextTrackChanged(textTrack: Track?) {
        PKLog.debug("textTrackChanged event")
        
        if let track = textTrack {
            if (track.language != nil) {
                self.kavaData.currentCaptionLanguage = track.language
                self.sendAnalyticsEvent(event: KavaEventType.captions)
            }
        }
    }
    
    private func handleError(error: NSError?) {
        PKLog.debug("error event")
        
        if let err = error {
            self.kavaData.errorCode = err.code
            self.sendAnalyticsEvent(event: KavaEventType.error)
        }
    }
    
    private func sendMediaLoaded() {
        if !self.kavaData.isMediaLoaded {
            self.kavaData.isMediaLoaded = true
            
            sendAnalyticsEvent(event: KavaEventType.impression)
        }
    }
    
    private func updateDeliveryType(mediaFormat: PKMediaSource.MediaFormat) {
        if (mediaFormat == PKMediaSource.MediaFormat.hls) {
            self.kavaData.deliveryType = KavaPluginData.DeliveryType.hls.rawValue
        } else {
            self.kavaData.deliveryType = KavaPluginData.DeliveryType.url.rawValue
        }
    }
}
