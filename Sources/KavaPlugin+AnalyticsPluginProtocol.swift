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
            PlayerEvent.textTrackChanged,
            PlayerEvent.videoTrackChanged,
            PlayerEvent.error
        ]
    }
    
 public func registerEvents() {
        self.messageBus?.addObserver(self, events: playerEventsToRegister, block: { [weak self] event in
            guard let strongSelf = self else { return }
            
            if type(of: event) == PlayerEvent.stateChanged {
                strongSelf.handleStateChanged(event: event)
            } else if type(of: event) == PlayerEvent.loadedMetadata {
                strongSelf.handleLoadedMetadata()
            } else if type(of: event) == PlayerEvent.play {
                strongSelf.handlePlay()
            } else if type(of: event) == PlayerEvent.pause {
                strongSelf.handlePause()
            } else if type(of: event) == PlayerEvent.playing {
                strongSelf.handlePlaying()
            } else if type(of: event) == PlayerEvent.seeking {
                strongSelf.handleSeeking(targetSeekPosition: event.targetSeekPosition)
            } else if type(of: event) == PlayerEvent.sourceSelected {
                strongSelf.handleSourceSelected(mediaSource: event.mediaSource)
            } else if type(of: event) == PlayerEvent.ended {
                strongSelf.handleEnded()
            } else if type(of: event) == PlayerEvent.videoTrackChanged {
                strongSelf.handleVideoTrackChanged(videoTrack: event.bitrate)
            } else if type(of: event) == PlayerEvent.textTrackChanged {
                strongSelf.handleTextTrackChanged(textTrack: event.selectedTrack)
            } else if type(of: event) == PlayerEvent.error {
                strongSelf.handleError(error: event.error)
            } else {
                assertionFailure("all player events must be handled")
            }
        })
        
        self.messageBus?.addObserver(self, events: [AdEvent.error], block: { [weak self] (event) in
            guard let strongSelf = self else { return }
            strongSelf.handleError(error: event.error)
        })
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
        self.sendMediaLoaded()
    }
    
    private func handlePlay() {
        PKLog.debug("play event")
        
        if self.isFirstPlay {
            self.joinTimeStart = Date().timeIntervalSince1970
        }
        
        self.sendAnalyticsEvent(event: KavaEventType.playRequest)
        
        if self.sentPlaybackPoints[KavaEventType.playReached100Percent] == true {
            self.sendAnalyticsEvent(event: KavaEventType.replay)
        }
    }
    
    private func handlePause() {
        PKLog.debug("pause event")
        self.kavaData.isPaused = true
        self.sendAnalyticsEvent(event: KavaEventType.pause)
        self.stopViewTimer()
    }
    
    private func handlePlaying() {
        PKLog.debug("playing event")
        self.kavaData.joinTime = nil
        if self.isFirstPlay {
            self.isFirstPlay = false
            self.kavaData.joinTime = Date().timeIntervalSince1970 - self.joinTimeStart
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
            self.indicatedBitrate = bitrate.doubleValue
            self.sendAnalyticsEvent(event: KavaEventType.flavorSwitched)
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
