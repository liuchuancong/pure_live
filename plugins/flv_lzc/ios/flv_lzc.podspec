#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#
Pod::Spec.new do |s|
  s.name             = 'flv_lzc'
  s.version          = '1.0.0'
  s.summary          = 'Flutter plugin for ijkplayer'
  s.description      = <<-DESC
Flutter plugin for ijkplayer
                       DESC
  s.homepage         = 'https://github.com/befovy/fijkplayer'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'befovy' => 'befovy@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'

  s.static_framework = true

  # @ uncomment next 3 lines to debug or use your custom ijkplayer build
  # 去除下面 3 行代码开头的注释 #，以便于进行调试或者使用自定义构建的 ijkplayer 产物
  # s.preserve_paths = 'Frameworks/*.framework'
  # s.vendored_frameworks = 'Frameworks/IJKMediaPlayer.framework'
  # s.xcconfig = { 'LD_RUNPATH_SEARCH_PATHS' => '"$(PODS_ROOT)/Frameworks/"' }

  s.libraries = "bz2", "z", "stdc++"
  s.dependency 'Flutter'

  # s.use_frameworks!

  s.dependency 'BIJKPlayer', '~> 0.7.16'

  s.ios.deployment_target = '8.0'
end
