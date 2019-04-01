
suffix = '-dev'   # Dev mode
# suffix = ''       # Release

Pod::Spec.new do |s|
    
    s.name                    = 'PlayKitKava'
    s.version                 = '1.0.5' + suffix
    s.summary                 = 'PlayKitKava -- Analytics framework for iOS'
    s.homepage                = 'https://github.com/kaltura/playkit-ios-kava'
    s.license                 = { :type => 'AGPLv3', :file => 'LICENSE' }
    s.author                  = { 'Kaltura' => 'community@kaltura.com' }
    s.source                  = { :git => 'https://github.com/kaltura/playkit-ios-kava.git', :tag => 'v' + s.version.to_s }
    s.swift_version           = '4.2'
    
    s.ios.deployment_target   = '9.0'
    s.tvos.deployment_target  = '9.0'

    s.source_files            = 'Sources/*'

    s.dependency 'PlayKit/Core'
    s.dependency 'PlayKit/AnalyticsCommon'
end

# To add playkit kava as dependecy use: s.dependency 'PlayKitKava', 'version_number'
