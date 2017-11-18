---
title: PlayKit Kava for iOS
---

# PlayKit Kava for iOS

{:.no_toc}

This project is the new client analytics project of Kaltura.

With Kava project, Kaltura real time analytics for live and on-demand video, you'll get historical or near real-time, raw or summarized data Kaltura partners need to truly understand how, when, and where their content is seen and shared by viewers. What keeps viewers watching? When do they lose interest? What do they share? Actionable Analytics ends the guesswork.

With the clear numbers in hand, Kaltura’s partner can build a content and monetization strategy that really works.

* TOC
{:toc}

## Usage  

To enable the Youbora Stats Plugin on iOS devices for the Kaltura Video Player, add the following line to your Podfile: 

```ruby
pod "PlayKitKava"
```

### Register Plugin

>Note: Our recommandation is to register on AppDelegate, see sample below.

```swift
PlayKitManager.shared.registerPlugin(KavaPlugin.self)
```

### Create a config and load player


```swift
let kavaConfig = KavaPluginConfig.init(partnerId: 1424501 , ks: nil, playbackContext: nil, referrer: nil, customVar1: nil, customVar2: nil, customVar3: nil)
            kavaConfig.playbackType = KavaPluginConfig.PlaybackType.vod
            let pluginConfig = PluginConfig(config: [KavaPlugin.pluginName: kavaConfig])
```

>Note: Only then load player with Plugin Config.

```swift
            self.player = try PlayKitManager.shared.loadPlayer(pluginConfig: pluginConfig)
```

<details><summary>Kava Plugin Events</summary><p>
    
```swift
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
```
</p></details>

### Kava Basic Sample

For a basic Kava sample [click here](https://github.com/kaltura/playkit-ios-samples/tree/develop/KavaPluginSample)
