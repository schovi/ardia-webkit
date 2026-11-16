Pod::Spec.new do |s|
  s.name           = 'ArdiaCore'
  s.version        = '0.0.0'
  s.summary        = 'Ardia on ArdiaCore (our own Chromium layer) for React Native macOS'
  s.author         = ''
  s.homepage       = 'https://github.com/ardia'
  s.license        = 'Apache-2.0'
  s.platforms      = { :osx => '14.0' }
  s.source         = { git: '' }
  s.static_framework = true
  s.dependency 'ExpoModulesCore'
  s.frameworks     = 'WebKit'
  s.source_files   = '*.h', '*.swift', 'webkit/*.mm', 'ArdiaLaunchConfig.mm', 'ArdiaEvents.mm', 'ArdiaTransferLedger.mm', 'ArdiaDownloadMover.mm', 'ArdiaNowPlaying.mm', 'ArdiaFieldTiming.mm', 'ArdiaPixelGridModule.mm'
  s.public_header_files = 'ArdiaHost.h', 'ArdiaWebView.h', 'ArdiaTabStrip.h', 'ArdiaEngineBridge.h', 'ArdiaServices.h', 'ArdiaContentBlocker.h', 'ArdiaFavicons.h', 'ArdiaSwipe.h', 'ArdiaChromeWindowHost.h', 'ArdiaLaunchConfig.h', 'ArdiaEvents.h', 'ArdiaNowPlaying.h', 'ArdiaTransferLedger.h', 'ArdiaDownloadMover.h'
  s.resources      = 'page_script.js'
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++20',
  }
end
