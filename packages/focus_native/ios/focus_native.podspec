Pod::Spec.new do |s|
  s.name             = 'focus_native'
  s.version          = '0.1.0'
  s.summary          = 'Focus Reset native iOS bridge (notifications, calendar, time zone).'
  s.description      = 'Local notifications via UserNotifications, read-only Apple Calendar via EventKit, and the device time zone.'
  s.homepage         = 'https://github.com/focus-reset'
  s.license          = { :type => 'Proprietary', :text => 'Proprietary' }
  s.author           = { 'Focus Reset' => 'support@focusreset.app' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform         = :ios, '12.0'
  s.frameworks       = 'UserNotifications', 'EventKit'
  # iOS 16+ only; weak-linked so older iOS versions still launch.
  s.weak_frameworks  = 'FamilyControls', 'ManagedSettings', 'SwiftUI'
  s.swift_version    = '5.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
end
