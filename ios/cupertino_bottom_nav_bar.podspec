Pod::Spec.new do |s|
  s.name             = 'cupertino_bottom_nav_bar'
  s.version          = '0.2.1'
  s.summary          = 'A Flutter navigation dock with native iOS glass presentation.'
  s.description      = 'Presentation-only UIKit navigation with resolved Flutter items and selection.'
  s.homepage         = 'https://pub.dev/packages/cupertino_bottom_nav_bar'
  s.license          = { :type => 'MIT', :file => '../LICENSE' }
  s.author           = 'Raghav Verma'
  s.source           = { :path => '.' }
  s.source_files     = 'cupertino_bottom_nav_bar/Sources/cupertino_bottom_nav_bar/**/*.swift'
  s.dependency 'Flutter'
  s.platform         = :ios, '15.0'
  s.frameworks       = 'UIKit'
  s.swift_version    = '5.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.resource_bundles = {
    'cupertino_bottom_nav_bar_privacy' => [
      'cupertino_bottom_nav_bar/Sources/cupertino_bottom_nav_bar/PrivacyInfo.xcprivacy'
    ]
  }
end
