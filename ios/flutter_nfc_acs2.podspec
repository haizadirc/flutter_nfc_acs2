#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint flutter_nfc_acs2.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'flutter_nfc_acs2'
  s.version          = '0.3.0'
  s.summary          = 'A plugin for communicating with the ACR1255U-J1 BT reader from Advanced Card Systems Ltd using SPM and modern native APIs.'
  s.description      = <<-DESC
A Flutter plugin for communicating with Bluetooth ACS ACR NFC card readers.
                       DESC
  s.homepage         = 'https://github.com/hidayatulrohani94/flutter_nfc_acs'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Nur Hidayatul Rohani MOKTAR' => 'info@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '12.0'
  s.swift_version = '5.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
end
