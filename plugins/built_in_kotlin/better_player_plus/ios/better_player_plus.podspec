#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#
Pod::Spec.new do |s|
  s.name             = 'better_player_plus'
  s.version          = '1.3.5'
  s.summary          = 'Advanced video player for Flutter with advanced configuration options.'
  s.description      = <<-DESC
Advanced video player for Flutter, based on video_player and inspired by Chewie and Better Player. 
It solves many common use cases out of the box and is easy to integrate.
                       DESC
  s.homepage         = 'https://github.com/SunnatilloShavkatov/betterplayer.git'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Sunnatillo Shavkatov' => 'sunnatillo.shavkatov@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files = 'better_player_plus/Sources/better_player_plus/**/*'
  s.exclude_files = 'better_player_plus/Sources/better_player_plus/BetterPlayerPlugin.{h,m}'
  s.public_header_files = 'better_player_plus/Sources/better_player_plus/**/*.h'
  s.dependency 'Flutter'
  s.dependency 'Cache', '~> 6.0.0'
  
  s.platform = :ios, '13.0'
  s.swift_version = '5.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'VALID_ARCHS[sdk=iphonesimulator*]' => 'x86_64' }
end
