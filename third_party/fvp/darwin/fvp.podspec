#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint fvp.podspec` to validate before publishing.
# Run `flutter clean` and rebuild to sync podspec changes
#
Pod::Spec.new do |s|
  s.name             = 'fvp'
  s.version          = '0.38.1'
  s.summary          = 'libmdk based Flutter video player plugin'
  s.description      = <<-DESC
Flutter video player plugin.
                       DESC
  s.homepage         = 'https://mediadevkit.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Wang Bin' => 'wbsecg1@gmail.com' }

  s.compiler_flags   = '-Wno-documentation', '-std=c++20'
  s.frameworks       = 'AVFoundation'
  s.osx.frameworks    = 'FlutterMacOS'
  #s.osx.pod_target_xcconfig  =  { 'OTHER_LDFLAGS'  =>  '-framework FlutterMacOS'  }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'
  s.ios.dependency 'Flutter'
  s.osx.dependency 'FlutterMacOS'
  s.ios.deployment_target = '12.0'
  s.osx.deployment_target = '10.13'
  s.dependency 'mdk', '~> 0.38.0'

#  s.platform = :osx, '10.11'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.resource_bundles = {'fvp_privacy' => ['PrivacyInfo.xcprivacy']}
#  s.swift_version = '5.0'
  s.prepare_command = <<-CMD
    FVP_VERSION=`grep 'version: ' ../pubspec.yaml | head -1 | awk '{print $2}'`
    echo '#pragma once\n#define FVP_VERSION "'$FVP_VERSION'"' > ../lib/src/version.h
  CMD
end
