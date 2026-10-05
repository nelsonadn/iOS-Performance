Pod::Spec.new do |s|
  s.name = 'IOSPerformanceCore'
  s.version = '0.1.0'
  s.summary = 'Shared Swift iOS performance measurement core'
  s.license = { :type => 'MIT' }
  s.author = 'iOS Performance contributors'
  s.homepage = 'https://example.invalid/ios-performance'
  s.platform = :ios, '15.0'
  s.source = { :git => 'https://example.invalid/ios-performance.git', :tag => s.version.to_s }
  s.source_files = 'Sources/IOSPerformanceCore/**/*.swift'
  s.swift_version = '6.0'
end
