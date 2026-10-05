Pod::Spec.new do |s|
  s.name = 'IOSPerformanceReactNative'
  s.version = '0.1.0'
  s.summary = 'Thin React Native bridge to IOSPerformanceCore'
  s.license = { :type => 'MIT' }
  s.author = 'iOS Performance contributors'
  s.homepage = 'https://example.invalid/ios-performance'
  s.platform = :ios, '15.0'
  s.source = { :git => 'https://example.invalid/ios-performance.git', :tag => s.version.to_s }
  s.source_files = 'ios/**/*.{h,m,mm,swift}', '../ios-core/Sources/IOSPerformanceCore/**/*.swift'
  s.dependency 'React-Core'
  s.swift_version = '6.0'
end
