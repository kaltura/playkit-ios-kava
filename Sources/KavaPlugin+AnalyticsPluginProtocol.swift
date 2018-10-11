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
            PlayerEvent.durationChanged,
            PlayerEvent.play,
            PlayerEvent.pause,
            PlayerEvent.playing,
            PlayerEvent.seeking,
            PlayerEvent.sourceSelected,
            PlayerEvent.ended,
            PlayerEvent.textTrackChanged,
            PlayerEvent.audioTrackChanged,
            PlayerEvent.videoTrackChanged,
            PlayerEvent.error
        ]
    }
    
    public func registerEvents() {
        self.messageBus?.addObserver(self, events: playerEventsToRegister, block: { [weak self] event in
            guard let strongSelf = self else { return }
            
            switch event {
            case is PlayerEvent.StateChanged:
                strongSelf.handleStateChanged(event: event)
            case is PlayerEvent.LoadedMetadata:
                strongSelf.handleLoadedMetadata()
            case is PlayerEvent.DurationChanged:
                strongSelf.duration = event.duration as! TimeInterval
            case is PlayerEvent.Play:
                strongSelf.handlePlay()
            case is PlayerEvent.Pause:
                strongSelf.handlePause()
            case is PlayerEvent.Playing:
                strongSelf.handlePlaying()
            case is PlayerEvent.Seeking:
                strongSelf.handleSeeking(targetSeekPosition: event.targetSeekPosition)
            case is PlayerEvent.SourceSelected:
                strongSelf.handleSourceSelected(mediaSource: event.mediaSource)
            case is PlayerEvent.Ended:
                strongSelf.handleEnded()
            case is PlayerEvent.VideoTrackChanged:
                strongSelf.handleVideoTrackChanged(event.bitrate)
            case is PlayerEvent.AudioTrackChanged:
                strongSelf.handleAudioTrackChanged(event.selectedTrack)
            case is PlayerEvent.TextTrackChanged:
                strongSelf.handleTextTrackChanged(event.selectedTrack)
            case is PlayerEvent.Error:
                strongSelf.handleError(error: event.error)
            default:
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
        PKLog.trace("state changed event: \(event)")
        
        switch event.newState {
        case .ready:
            PKLog.trace("media ready")
            
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
        PKLog.trace("loadedMetadata event")
        self.sendMediaLoaded()
    }
    
    private func handlePlay() {
        PKLog.trace("play event")
        
        if self.isFirstPlay {
            self.joinTimeStart = Date().timeIntervalSince1970
        }
        
        self.sendAnalyticsEvent(event: KavaEventType.playRequest)
        
        if self.sentPlaybackPoints[KavaEventType.playReached100Percent] == true {
            self.sendAnalyticsEvent(event: KavaEventType.replay)
        }
    }
    
    private func handlePause() {
        PKLog.trace("pause event")
        self.kavaData.isPaused = true
        self.sendAnalyticsEvent(event: KavaEventType.pause)
        self.stopViewTimer()
    }
    
    private func handlePlaying() {
        PKLog.trace("playing event")
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
        PKLog.trace("seeking event")
        
        if let seekPosition = targetSeekPosition {
            self.kavaData.targetSeekPosition = Double(truncating: seekPosition)
        }
        
        self.sendAnalyticsEvent(event: KavaEventType.seek)
    }
    
    private func handleSourceSelected(mediaSource: PKMediaSource?) {
        PKLog.trace("sourceSelected event")
        
        if let source = mediaSource {
            self.kavaData.selectedSource = source
            self.updateDeliveryType(mediaFormat: source.mediaFormat)
        }
    }
    
    private func handleEnded() {
        PKLog.trace("ended event")
        self.sendPercentageReachedEvent(percentage: 100)
        self.stopViewTimer()
    }
    
    private func handleVideoTrackChanged(_ videoTrack: NSNumber?) {
        PKLog.trace("videoTrackChanged event")
        
        if let bitrate = videoTrack {
            self.kavaData.indicatedBitrate = bitrate.doubleValue
            self.sendAnalyticsEvent(event: KavaEventType.flavorSwitched)
        }
    }
    
    private func handleAudioTrackChanged(_ audioTrack: Track?) {
        PKLog.trace("audioTrackChanged event")
        
        if let track = audioTrack {
            if (track.language != nil) {
                self.kavaData.currentAudioLanguage = track.language
                self.sendAnalyticsEvent(event: KavaEventType.audioSelected)
            }
        }
    }
    
    private func handleTextTrackChanged(_ textTrack: Track?) {
        PKLog.trace("textTrackChanged event")
        
        let textOffDisplay: String = "Off"
        
        if let track = textTrack {
            if (track.language != nil) {
                self.kavaData.currentCaptionLanguage = track.language
                self.sendAnalyticsEvent(event: KavaEventType.captions)
            } else {
                if (track.title == textOffDisplay) {
                    self.kavaData.currentCaptionLanguage = "none"
                    self.sendAnalyticsEvent(event: KavaEventType.captions)
                }
            }
        }
    }
    
    private func handleError(error: NSError?) {
        PKLog.trace("error event")
        
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
