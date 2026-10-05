Pod::Spec.new do |s|
  s.name = 'IOSPerformanceCapacitor'
  s.version = '0.1.0'
  s.summary = 'Thin Capacitor bridge to IOSPerformanceCore'
  s.license = { :type => 'MIT' }
  s.author = 'iOS Performance contributors'
  s.homepage = 'https://example.invalid/ios-performance'
  s.platform = :ios, '15.0'
  s.source = { :git => 'https://example.invalid/ios-performance.git', :tag => s.version.to_s }
  s.source_files = 'Sources/**/*.{h,m,swift}', '../../ios-core/Sources/IOSPerformanceCore/**/*.swift'
  s.dependency 'Capacitor'
  s.swift_version = '6.0'
end
