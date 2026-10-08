#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint flutter_exit_app.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'flutter_exit_app'
  s.version          = '2.1.2'
  s.summary          = "A flutter plugin provides the best way to exit the app doesn't call exit(0) in dart code."
  s.description      = <<-DESC
  A flutter plugin provides the best way to exit the app doesn't call exit(0) in dart code.
                       DESC
  s.homepage         = 'https://github.com/xang555/flutter_exit_app'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Xangnam' => 'xang.ultimate@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files = 'flutter_exit_app/Sources/flutter_exit_app/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
