Pod::Spec.new do |s|
  s.name = 'IosPerformanceCapacitor'
  s.version = '0.1.0'
  s.summary = 'Thin Capacitor bridge to IOSPerformanceCore'
  s.license = { :type => 'MIT' }
  s.author = 'iOS Performance contributors'
  s.homepage = 'https://example.invalid/ios-performance'
  s.platform = :ios, '15.0'
  s.source = { :git => 'https://example.invalid/ios-performance.git', :tag => s.version.to_s }
  s.source_files = 'ios/Sources/**/*.{h,m,swift}'
  s.dependency 'Capacitor'
  s.dependency 'IOSPerformanceCore'
  s.swift_version = '6.0'
end
