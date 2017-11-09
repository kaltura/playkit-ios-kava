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
            PlayerEvent.trackChanged,
            PlayerEvent.error
        ]
    }
    
    public func registerEvents() {
        PKLog.debug("register player events")
        
        self.playerEventsToRegister.forEach { event in
            PKLog.debug("Register event: \(event.self)")
            
            switch event {
            case let e where e.self == PlayerEvent.stateChanged:
                self.messageBus?.addObserver(self, events: [e.self]) { [weak self] event in
                    guard let strongSelf = self else { return }
                    PKLog.debug("state changed event: \(event)")
                    if type(of: event) == PlayerEvent.stateChanged {
                        strongSelf.handleStateChanged(event: event)
                    }
                }
                
            case let e where e.self == PlayerEvent.loadedMetadata:
                self.messageBus?.addObserver(self, events: [e.self], block: { [weak self] (event) in
                    guard let strongSelf = self else { return }
                    PKLog.debug("loadedMetadata event: \(event)")
                    strongSelf.sendMediaLoaded()
                })
                
            case let e where e.self == PlayerEvent.play:
                self.messageBus?.addObserver(self, events: [e.self], block: { [weak self] (event) in
                    guard let strongSelf = self else { return }
                    PKLog.debug("play event: \(event)")
                    strongSelf.sendAnalyticsEvent(action: KavaEventType.playRequest)
                    
                    if strongSelf.sentPlaybackPoints[KavaEventType.playReached100Percent] == true {
                        strongSelf.sendAnalyticsEvent(action: KavaEventType.replay)
                    }
                })
                
            case let e where e.self == PlayerEvent.pause:
                self.messageBus?.addObserver(self, events: [e.self], block: { [weak self] (event) in
                    guard let strongSelf = self else { return }
                    PKLog.debug("pause event: \(event)")
                    strongSelf.isPaused = true
                    strongSelf.sendAnalyticsEvent(action: KavaEventType.pause)
                    strongSelf.stopViewTimer()
                })
                
            case let e where e.self == PlayerEvent.playing:
                self.messageBus?.addObserver(self, events: [e.self], block: { [weak self] (event) in
                    guard let strongSelf = self else { return }
                    PKLog.debug("playing event: \(event)")
                    if strongSelf.isFirstPlay {
                        strongSelf.isFirstPlay = false
                        strongSelf.sendAnalyticsEvent(action: KavaEventType.play)
                    } else if strongSelf.isPaused {
                        strongSelf.sendAnalyticsEvent(action: KavaEventType.resume)
                    }
                    
                    strongSelf.isPaused = false
                    strongSelf.setupViewTimer()
                })
                
            case let e where e.self == PlayerEvent.seeking:
                self.messageBus?.addObserver(self, events: [e.self], block: { [weak self] (event) in
                    PKLog.debug("seeking event: \(event)")
                     
                    if let seekPosition = event.targetSeekPosition {
                        self?.targetSeekPosition = Double(truncating: seekPosition)
                    }
                    
                    self?.sendAnalyticsEvent(action: KavaEventType.seek)
                })
                
            case let e where e.self == PlayerEvent.sourceSelected:
                self.messageBus?.addObserver(self, events: [e.self], block: { [weak self] (event) in
                    guard let strongSelf = self else { return }
                    PKLog.debug("sourceSelected event: \(event)")
                    strongSelf.selectedSource = event.mediaSource
                    strongSelf.updateDeliveryType(mediaFormat: (strongSelf.selectedSource?.mediaFormat)!)
                    // Reset flags when source was changed
                    strongSelf.resetPlayerFlags()
                })
                
            case let e where e.self == PlayerEvent.ended:
                self.messageBus?.addObserver(self, events: [e.self], block: { [weak self] (event) in
                    guard let strongSelf = self else { return }
                    PKLog.debug("ended event: \(event)")
                    strongSelf.sendPercentageReachedEvent(percentage: 100)
                    strongSelf.stopViewTimer()
                })
                
            case let e where e.self == PlayerEvent.playbackInfo:
                self.messageBus?.addObserver(self, events: [e.self], block: { [weak self] (event) in
                    guard let strongSelf = self else { return }
                    PKLog.debug("playbackInfo event: \(event)")
                    strongSelf.indicatedBitrate = event.playbackInfo?.indicatedBitrate
                })
            
            case let e where e.self == PlayerEvent.trackChanged:
                self.messageBus?.addObserver(self, events: [e.self], block: { [weak self] (event) in
                    guard let strongSelf = self else { return }
                    PKLog.debug("trackChanged event: \(event)")
                    if let track = event.selectedTrack {
                        if (track.title.contains("event.selectedTrack?.title")) {
                            strongSelf.currentCaptionLanguage = event.selectedTrack?.language
                            strongSelf.sendAnalyticsEvent(action: KavaEventType.captions)
                        }
                    }
                })
                
            case let e where e.self == PlayerEvent.error:
                self.messageBus?.addObserver(self, events: [e.self], block: { [weak self] (event) in
                    guard let strongSelf = self else { return }
                    PKLog.debug("PlayerEvent error event: \(event)")
                    strongSelf.errorCode = (event.error?.code)!
                    strongSelf.sendAnalyticsEvent(action: KavaEventType.error)
                })
            default: assertionFailure("all events must be handled")
            }
        }
        
        self.messageBus?.addObserver(self, events: [AdEvent.error], block: { [weak self] (event) in
            guard let strongSelf = self else { return }
            PKLog.debug("AdEvent error event: \(event)")
            strongSelf.errorCode = (event.error?.code)!
            strongSelf.sendAnalyticsEvent(action: KavaEventType.error)
        })
    }
    
    /************************************************************/
    // MARK: Private Implementation
    /************************************************************/
    
    private func handleStateChanged(event: PKEvent) {
        switch event.newState {
        case .idle:
            PKLog.debug("state changed to idle")
        case .ended:
            PKLog.info("media ended")
        case .ready:
            if let _ = bufferingStartTime {
                totalBufferingInCurrentInterval += -bufferingStartTime!.timeIntervalSinceNow
                bufferingStartTime = nil
            }
            
            self.sendMediaLoaded()
            self.registerToBoundaries()
        case .buffering:
            bufferingStartTime = Date()
        case .error: break
        case .unknown: break
        }
    }
    
    private func sendMediaLoaded() {
        if !self.isMediaLoaded {
            self.isMediaLoaded = true
            
            sendAnalyticsEvent(action: KavaEventType.impression)
        }
    }
    
    private func updateDeliveryType(mediaFormat: PKMediaSource.MediaFormat) {
        if (mediaFormat == PKMediaSource.MediaFormat.hls) {
            self.deliveryType = self.deliveryTypeHls
        } else {
            self.deliveryType = self.deliveryTypeOther
        }
    }
}
