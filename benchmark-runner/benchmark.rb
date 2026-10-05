require 'yaml'
require 'json'
require 'optparse'
require 'open3'
require 'fileutils'
require 'time'
require 'csv'

def redact_output(text)
  text = text.gsub(/-----BEGIN [^-]*PRIVATE KEY-----.*?-----END [^-]*PRIVATE KEY-----/m, '[REDACTED PRIVATE KEY]')
  text = text.gsub(/(authorization\s*[:=]\s*(?:bearer\s+)?)[^\s,;"']+/i, '\\1[REDACTED]')
  text = text.gsub(/((?:access[_-]?token|refresh[_-]?token|api[_-]?key|client[_-]?secret|password|passwd|secret)\s*[:=]\s*["']?)[^\s,;"'}]+/i, '\\1[REDACTED]')
  text = text.gsub(/\beyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\b/, '[REDACTED JWT]')
  text.gsub(/\bAKIA[0-9A-Z]{16}\b/, '[REDACTED AWS KEY]')
end

options = { runs: 10, config: File.expand_path('../performance-projects.yml', __dir__) }
OptionParser.new do |p|
  p.on('--config FILE') { |v| options[:config] = File.expand_path(v) }
  p.on('--project KEY') { |v| options[:project] = v }
  p.on('--scenario NAME') { |v| options[:scenario] = v }
  p.on('--runs N', Integer) { |v| options[:runs] = v }
  p.on('--destination DEST') { |v| options[:destination] = v }
end.parse!
abort 'required: --project KEY --scenario NAME' unless options[:project] && options[:scenario]
abort '--runs must be positive' unless options[:runs].positive?
config_path = File.expand_path(options[:config])
abort "Config not found: #{config_path}" unless File.file?(config_path)
config = YAML.safe_load_file(config_path, permitted_classes: [], aliases: false)
project = config.fetch('projects', {}).fetch(options[:project]) { abort "Unknown project key: #{options[:project]}" }
repo = File.expand_path(project.fetch('path'), File.dirname(config_path))
abort "External repository does not exist: #{repo}" unless File.directory?(repo)
abort "Configured path is not a Git repository: #{repo}" unless File.exist?(File.join(repo, '.git'))
abort "Unsupported framework: #{project['framework']}" unless %w[react-native capacitor].include?(project['framework'])
ios = project.fetch('ios')
container_key = ios['workspace'] ? 'workspace' : 'project'
abort 'Configure ios.workspace or ios.project' unless ios[container_key]
container = File.expand_path(ios.fetch(container_key), repo)
abort "Xcode #{container_key} not found: #{container}" unless File.exist?(container)
abort 'Configure ios.scheme and ios.bundleId' unless ios['scheme'] && ios['bundleId']

runner_root = File.expand_path('..', __dir__)
result_root = File.expand_path(project.fetch('results', "results/#{options[:project]}"), File.dirname(config_path))
unless result_root == runner_root || result_root.start_with?(runner_root + File::SEPARATOR)
  abort "Result directory must be inside iOS-Performance: #{result_root}"
end
scenario_dir = File.join(result_root, options[:scenario].downcase.gsub(/[^a-z0-9_-]/, '_'))
FileUtils.mkdir_p(scenario_dir)
batch_dir = File.join(scenario_dir, 'batches', "#{Time.now.utc.strftime('%Y%m%dT%H%M%S')}-#{Process.pid}")
FileUtils.mkdir_p(batch_dir)
scheme = ios.fetch('scheme')
configuration = ios.fetch('configuration', 'Release')
destination = options[:destination] || ios['destination']
base = ['xcodebuild', container_key == 'workspace' ? '-workspace' : '-project', container, '-scheme', scheme, '-configuration', configuration]
base += ['-destination', destination] if destination && !destination.empty?
derived = File.join(scenario_dir, 'DerivedData')
build_command = base + ['-derivedDataPath', derived, 'build']
puts "Building #{project.fetch('name', options[:project])} (#{project.fetch('framework')}) from #{repo}"
output, status = Open3.capture2e(*build_command, chdir: repo)
File.write(File.join(scenario_dir, 'build.log'), redact_output(output))
abort "xcodebuild build failed; see #{scenario_dir}/build.log" unless status.success?

app_info = {}
info_plists = Dir.glob(File.join(derived, 'Build', 'Products', '**', '*.app', 'Info.plist'))
info_plists.each do |plist|
  identifier, = Open3.capture2('/usr/libexec/PlistBuddy', '-c', 'Print:CFBundleIdentifier', plist)
  next unless identifier.strip == ios['bundleId']
  %w[CFBundleShortVersionString CFBundleVersion].each do |key|
    value, command_status = Open3.capture2('/usr/libexec/PlistBuddy', '-c', "Print:#{key}", plist)
    app_info[key] = value.strip if command_status.success?
  end
  break
end

test_target = ios['testTarget']
abort 'Build succeeded, but no ios.testTarget is configured to execute a scenario.' unless test_target
test_selector = ios['test'] || options[:scenario]
runs = []
options[:runs].times do |index|
  run_number = index + 1
  xcresult = File.join(batch_dir, "run-#{run_number}.xcresult")
  test_command = base + ['-derivedDataPath', derived, '-resultBundlePath', xcresult, "-only-testing:#{test_target}/#{test_selector}", 'test']
  # Keep target repositories read-only; xcodebuild outputs stay under iOS-Performance/results.
  output, status = Open3.capture2e(*test_command, chdir: repo)
  File.write(File.join(batch_dir, "run-#{run_number}.log"), redact_output(output))
  abort "Scenario run #{run_number} failed; see #{batch_dir}/run-#{run_number}.log" unless status.success?
  attachments = File.join(batch_dir, "run-#{run_number}-attachments")
  _attachment_output, attachment_status = Open3.capture2e('xcrun', 'xcresulttool', 'export', 'attachments', '--path', xcresult, '--output-path', attachments)
  sdk_results = []
  if attachment_status.success? && File.directory?(attachments)
    Dir.glob(File.join(attachments, '**', '*.json')).each do |json_path|
      begin
        parsed = JSON.parse(File.read(json_path))
        candidates = parsed.is_a?(Array) ? parsed : [parsed]
        sdk_results.concat(candidates.select { |candidate| candidate.is_a?(Hash) && candidate['durationMs'] && candidate['metrics'] })
      rescue JSON::ParserError
        next
      end
    end
  end
  normalized = sdk_results.map do |result|
    metrics = result.fetch('metrics', {})
    next unless result['name'].to_s.match?(/\A[A-Za-z0-9_.-]{1,80}\z/)
    safe_marks = Array(result['marks']).filter_map do |mark|
      next unless mark.is_a?(Hash) && mark['name'].to_s.match?(/\A[A-Za-z0-9_.-]{1,80}\z/) && mark['category'].to_s.match?(/\A[A-Za-z0-9_.-]{1,80}\z/)
      offset = mark['offsetMs']
      next unless offset.is_a?(Numeric) && offset.finite?
      { name: mark['name'], category: mark['category'], offset_ms: offset }
    end
    { name: result['name'], duration_ms: result['durationMs'], cpu_average_percent: metrics['cpuAveragePercent'], cpu_peak_percent: metrics['cpuPeakPercent'], memory_average_mb: metrics['memoryAverageMB'], memory_peak_mb: metrics['memoryPeakMB'], average_fps: metrics['averageFPS'], slow_frames: metrics['slowFrameCount'], marks: safe_marks }
  end.compact
  xctest_metrics = []
  xctest_device = nil
  metric_output, metric_status = Open3.capture2e('xcrun', 'xcresulttool', 'get', 'test-results', 'metrics', '--path', xcresult)
  if metric_status.success?
    File.write(File.join(batch_dir, "run-#{run_number}-xctest-metrics.json"), redact_output(metric_output))
    begin
      metric_doc = JSON.parse(metric_output)
      Array(metric_doc['testRuns']).each do |test_run|
        xctest_device ||= test_run.dig('device', 'deviceName').to_s.gsub(/[^A-Za-z0-9_. -]/, '').slice(0, 80) if test_run.dig('device', 'deviceName')
        Array(test_run['metrics']).each do |metric|
          xctest_metrics << { identifier: metric['identifier'].to_s.gsub(/[^A-Za-z0-9_.-]/, '').slice(0, 80), name: metric['displayName'].to_s.gsub(/[^A-Za-z0-9_. -]/, '').slice(0, 80), unit: metric['unitOfMeasurement'].to_s.gsub(/[^A-Za-z0-9_.% -]/, '').slice(0, 32), measurements: Array(metric['measurements']).select { |value| value.is_a?(Numeric) && value.finite? } }
        end
      end
    rescue JSON::ParserError
      xctest_metrics = []
    end
  end
  sdk_metadata = sdk_results.first && sdk_results.first['metadata'] || {}
  safe_metadata = %w[appVersion buildVersion osVersion].each_with_object({}) do |key, output|
    value = sdk_metadata[key].to_s
    output[key] = value if value.match?(/\A[A-Za-z0-9_.-]{1,80}\z/)
  end
  metadata = {
    project: options[:project], name: project.fetch('name', options[:project]), framework: project.fetch('framework'), scenario: options[:scenario],
    run: run_number, device: xctest_device || 'unspecified', destination: destination, configuration: configuration,
    appVersion: safe_metadata['appVersion'] || app_info['CFBundleShortVersionString'], buildVersion: safe_metadata['buildVersion'] || app_info['CFBundleVersion'], iOSVersion: safe_metadata['osVersion'],
    timestamp: Time.now.utc.iso8601, source: 'XCTEST', sdkMetrics: normalized, xctestMetrics: xctest_metrics
  }
  runs << metadata
  File.write(File.join(batch_dir, "run-#{run_number}.json"), JSON.pretty_generate(metadata) + "\n")
end
File.write(File.join(batch_dir, 'runs.json'), JSON.pretty_generate(runs) + "\n")
File.write(File.join(scenario_dir, 'runs.json'), JSON.pretty_generate(runs) + "\n")
csv_path = File.join(batch_dir, 'normalized.csv')
CSV.open(csv_path, 'w') do |csv|
  csv << %w[framework scenario run duration_ms cpu_avg cpu_peak memory_avg_mb memory_peak_mb fps_avg slow_frames]
  runs.each do |run|
    sample = Array(run[:sdkMetrics]).find { |item| item[:name].to_s.casecmp?(options[:scenario]) } || Array(run[:sdkMetrics]).first || {}
    csv << [run[:framework], run[:scenario], run[:run], sample[:duration_ms], sample[:cpu_average_percent], sample[:cpu_peak_percent], sample[:memory_average_mb], sample[:memory_peak_mb], sample[:average_fps], sample[:slow_frames]]
  end
end
puts "Completed #{runs.length} XCTest runs. Artifacts: #{batch_dir}"
puts 'No SDK exports were found in XCTest attachments.' if runs.all? { |run| run[:sdkMetrics].empty? }
