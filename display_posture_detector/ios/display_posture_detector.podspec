#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint display_posture_detector.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'display_posture_detector'
  s.version          = '0.0.2'
  s.summary          = 'Flutter plugin for detecting display posture, hinge bounds, and multi-display regions.'
  s.description      = <<-DESC
A Flutter plugin to detect display postures, hardware hinge bounds, orientation, screen metrics, and multi-display regions on foldables and tablets.
                       DESC
  s.homepage         = 'https://kauscoder.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Kaustav Halder' => 'contact@kauscoder.com' }
  s.source           = { :path => '.' }
  s.source_files = 'display_posture_detector/Sources/display_posture_detector/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '15.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # If your plugin requires a privacy manifest, for example if it uses any
  # required reason APIs, update the PrivacyInfo.xcprivacy file to describe your
  # plugin's privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'display_posture_detector_privacy' => ['display_posture_detector/Sources/display_posture_detector/PrivacyInfo.xcprivacy']}
end
