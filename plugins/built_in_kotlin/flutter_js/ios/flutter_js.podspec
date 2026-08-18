#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint flutter_js.podspec' to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'flutter_js'
  s.version          = '0.1.0'
  s.summary          = 'A Javascript engine to use with flutter. It uses quickjs on Android and JavascriptCore on IOS'
  s.description      = <<-DESC
A Javascript engine to use with flutter. It uses quickjs on Android and JavascriptCore on IOS
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '8.0'
  s.frameworks = 'JavaScriptCore'
  # Flutter.framework does not contain a i386 slice. Only x86_64 simulators are supported.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'VALID_ARCHS[sdk=iphonesimulator*]' => 'x86_64' }
  s.swift_version = '5.0'
end
