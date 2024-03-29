// ===================================================================================================
// Copyright (C) 2017 Kaltura Inc.
//
// Licensed under the AGPLv3 license, unless a different license for a
// particular library is specified in the applicable library path.
//
// You may obtain a copy of the License at
// https://www.gnu.org/licenses/agpl-3.0.html
// ===================================================================================================

import Foundation
import PlayKit

#if canImport(AnalyticsCommon)
    import AnalyticsCommon
#endif

extension KavaPlugin: AnalyticsPluginProtocol {
    
    /************************************************************/
    // MARK: - AnalyticsPluginProtocol
    /************************************************************/
    
    public var isFirstPlayRequest: Bool {
        get {
            return self.kavaData.isFirstPlayRequest
        }
        set {
            self.kavaData.isFirstPlayRequest = newValue
        }
    }
    
    public var isFirstPlay: Bool {
        get {
            return self.kavaData.isFirstPlay
        }
        set {
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
            PlayerEvent.playbackRate,
            PlayerEvent.seeking,
            PlayerEvent.sourceSelected,
            PlayerEvent.stopped,
            PlayerEvent.ended,
            PlayerEvent.replay,
            PlayerEvent.textTrackChanged,
            PlayerEvent.audioTrackChanged,
            PlayerEvent.videoTrackChanged,
            PlayerEvent.error
        ]
    }
    
    public func registerEvents() {
        self.messageBus?.addObserver(self, events: playerEventsToRegister, block: { [weak self] event in
            guard let self = self else { return }
            
            switch event {
            case is PlayerEvent.StateChanged:
                self.handleStateChanged(event: event)
            case is PlayerEvent.LoadedMetadata:
                self.handleLoadedMetadata()
            case is PlayerEvent.Play:
                self.handlePlay()
            case is PlayerEvent.Pause:
                self.handlePause()
            case is PlayerEvent.Playing:
                self.handlePlaying()
            case is PlayerEvent.Seeking:
                self.handleSeeking(targetSeekPosition: event.targetSeekPosition)
            case is PlayerEvent.SourceSelected:
                self.handleSourceSelected(mediaSource: event.mediaSource)
            case is PlayerEvent.Stopped:
                self.handleStopped()
            case is PlayerEvent.Ended:
                self.handleEnded()
            case is PlayerEvent.Replay:
                self.handleReplay()
            case is PlayerEvent.VideoTrackChanged:
                self.handleVideoTrackChanged(event.bitrate)
            case is PlayerEvent.AudioTrackChanged:
                self.handleAudioTrackChanged(event.selectedTrack)
            case is PlayerEvent.TextTrackChanged:
                self.handleTextTrackChanged(event.selectedTrack)
            case is PlayerEvent.Error:
                self.handleError(error: event.error)
            case is PlayerEvent.PlaybackRate:
                self.handlePlaybackRate(rate: event.palybackRate)
            default:
                assertionFailure("all player events must be handled")
            }
        })
    }
    
    public func unregisterEvents() {
        self.messageBus?.removeObserver(self, events: playerEventsToRegister)
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
            
            if self.rebufferStarted {
                self.rebufferStarted = false
                self.sendAnalyticsEvent(event: EventType.bufferEnd)
            }
            
            self.sendMediaLoaded()
            self.registerToBoundaries()
        case .buffering:
            bufferingStartTime = Date()
            
            if !self.isFirstPlay {
                self.rebufferStarted = true
                self.sendAnalyticsEvent(event: EventType.bufferStart)
            }
        case .ended:
            if self.rebufferStarted {
                self.rebufferStarted = false
                self.sendAnalyticsEvent(event: EventType.bufferEnd)
            }
        default: break
        }
    }
    
    private func handleLoadedMetadata() {
        PKLog.debug("loadedMetadata event")
        self.sendMediaLoaded()
    }
    
    private func handlePlay() {
        PKLog.debug("play event")
        
        if self.isFirstPlayRequest {
            self.isFirstPlayRequest = false
            self.joinTimeStart = Date().timeIntervalSince1970
            self.sendAnalyticsEvent(event: EventType.playRequest)
        }
    }
    
    private func handlePause() {
        PKLog.debug("pause event")
        self.kavaData.isPaused = true
        self.sendAnalyticsEvent(event: EventType.pause)
        self.stopViewTimer()
    }
    
    private func handlePlaying() {
        PKLog.debug("playing event")
        self.kavaData.joinTime = nil
        if self.isFirstPlay {
            self.isFirstPlay = false
            self.kavaData.joinTime = Date().timeIntervalSince1970 - self.joinTimeStart
            self.sendAnalyticsEvent(event: EventType.play)
            // We are not calling reportView() function because timer is currently nil.
            self.sendAnalyticsEvent(event: EventType.view)
        } else if self.kavaData.isPaused {
            self.sendAnalyticsEvent(event: EventType.resume)
        }
        self.kavaData.isPaused = false
        
        self.setupViewTimer()
    }
    
    private func handleSeeking(targetSeekPosition: NSNumber?) {
        PKLog.debug("seeking event")
        
        if let seekPosition = targetSeekPosition {
            self.kavaData.targetSeekPosition = Double(truncating: seekPosition)
        }
        
        self.sendAnalyticsEvent(event: EventType.seek)
    }
    
    private func handleSourceSelected(mediaSource: PKMediaSource?) {
        PKLog.debug("sourceSelected event")
        
        if let source = mediaSource {
            self.kavaData.selectedSource = source
            self.updateDeliveryType(mediaFormat: source.mediaFormat)
        }
    }
    
    private func handleStopped() {
        PKLog.debug("stopped event")
        self.stopViewTimer()
    }
    
    private func handleEnded() {
        PKLog.debug("ended event")
        self.sendPercentageReachedEvent(percentage: 100)
        self.stopViewTimer()
    }
    
    private func handleReplay() {
        PKLog.debug("replay event")
        self.sendAnalyticsEvent(event: EventType.replay)
    }
    
    private func handleVideoTrackChanged(_ videoTrack: NSNumber?) {
        PKLog.debug("videoTrackChanged event")
        
        if let bitrate = videoTrack {
            self.kavaData.indicatedBitrate = bitrate.doubleValue
            self.sendAnalyticsEvent(event: EventType.flavorSwitched)
        }
    }
    
    private func handleAudioTrackChanged(_ audioTrack: Track?) {
        PKLog.debug("audioTrackChanged event")
        
        if let track = audioTrack {
            if (track.language != nil) {
                self.kavaData.currentAudioLanguage = track.language
                self.sendAnalyticsEvent(event: EventType.audioSelected)
            }
        }
    }
    
    private func handleTextTrackChanged(_ textTrack: Track?) {
        PKLog.debug("textTrackChanged event")
        
        let textOffDisplay: String = "Off"
        
        if let track = textTrack {
            if (track.language != nil) {
                self.kavaData.currentCaptionLanguage = track.language
                self.sendAnalyticsEvent(event: EventType.captions)
            } else {
                if (track.title == textOffDisplay) {
                    self.kavaData.currentCaptionLanguage = "none"
                    self.sendAnalyticsEvent(event: EventType.captions)
                }
            }
        }
    }
    
    private func handleError(error: NSError?) {
        PKLog.debug("error event")
        
        if let err = error {
            self.kavaData.errorCode = err.code
            self.kavaData.errorDetails = err.localizedDescription
            if self.isFirstPlayRequest {
                self.kavaData.errorPosition = .prePlayRequest
            } else if self.isFirstPlay {
                self.kavaData.errorPosition = .videoStart
            } else {
                self.kavaData.errorPosition = .midStream
            }
            self.sendAnalyticsEvent(event: EventType.error)
        }
    }
    
    private func handlePlaybackRate(rate: NSNumber?) {
        PKLog.debug("PlaybackRateChanged event")
        
        if let rate = rate {
            self.kavaData.lastKnownPlaybackSpeed = rate.floatValue;
            self.sendAnalyticsEvent(event: EventType.speed)
        }
    }
    
    private func sendMediaLoaded() {
        if !self.kavaData.isMediaLoaded {
            self.kavaData.isMediaLoaded = true
            sendAnalyticsEvent(event: EventType.impression)
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
