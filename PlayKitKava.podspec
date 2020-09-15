
suffix = '.0000'   # Dev mode
# suffix = ''       # Release

Pod::Spec.new do |s|
    
    s.name                    = 'PlayKitKava'
    s.version                 = '1.6.0' + suffix
    s.summary                 = 'PlayKitKava -- Analytics framework for iOS'
    s.homepage                = 'https://github.com/kaltura/playkit-ios-kava'
    s.license                 = { :type => 'AGPLv3', :file => 'LICENSE' }
    s.author                  = { 'Kaltura' => 'community@kaltura.com' }
    s.source                  = { :git => 'https://github.com/kaltura/playkit-ios-kava.git', :tag => 'v' + s.version.to_s }
    s.swift_version           = '5.0'
    
    s.ios.deployment_target   = '9.0'
    s.tvos.deployment_target  = '9.0'

    s.source_files            = 'Sources/*'

    s.dependency 'PlayKit/AnalyticsCommon', '~> 3.18'
end

# To add playkit kava as dependecy use: s.dependency 'PlayKitKava', 'version_number'
