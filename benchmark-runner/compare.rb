require 'json'
require 'yaml'
require 'optparse'
require 'fileutils'
require 'time'

repo_root = File.expand_path('..', __dir__)
options = { root: File.join(repo_root, 'results'), config: File.join(repo_root, 'performance-projects.yml') }
options[:scenario] = ARGV.shift&.downcase unless ARGV.first&.start_with?('--')
OptionParser.new do |p|
  p.on('--scenario NAME') { |v| options[:scenario] = v.downcase }
  p.on('--projects A,B') { |v| options[:projects] = v.split(',') }
  p.on('--config FILE') { |v| options[:config] = File.expand_path(v) }
end.parse!
abort 'required: --scenario NAME' unless options[:scenario]
config = File.file?(options[:config]) ? YAML.safe_load_file(options[:config], permitted_classes: [], aliases: false) : { 'projects' => {} }
project_configs = config.fetch('projects', {})
projects = options[:projects] || project_configs.keys
project_results = lambda do |project|
  entry = project_configs[project] || {}
  path = File.expand_path(entry.fetch('results', File.join('results', project)), File.dirname(options[:config]))
  abort "Configured results directory must be inside iOS-Performance: #{path}" unless path == repo_root || path.start_with?(repo_root + File::SEPARATOR)
  path
end
records = projects.filter_map do |project|
  file = File.join(project_results.call(project), options[:scenario], 'runs.json')
  next unless File.file?(file)
  rows = JSON.parse(File.read(file))
  { project: project, runs: rows }
end
abort "No run data found for #{options[:scenario]}" if records.empty?
device_ids = records.flat_map { |row| row[:runs].filter_map { |run| run['deviceId'] } }.uniq
destinations = records.flat_map { |row| row[:runs].filter_map { |run| run['destination'] } }.uniq
abort "Refusing to compare different device IDs: #{device_ids.join(', ')}" if device_ids.length > 1
abort "Refusing to compare different destinations: #{destinations.join(', ')}" if destinations.length > 1
if device_ids.empty? && destinations.empty?
  warn 'Device identity is not recorded for these runs; same-device comparability cannot be verified.'
end
report = { scenario: options[:scenario].upcase, comparedAt: Time.now.utc.iso8601, projects: records }
comparison_dir = File.join(options[:root], 'comparisons', options[:scenario])
FileUtils.mkdir_p(comparison_dir)
puts "Scenario: #{report[:scenario]}"
metrics = %w[duration_ms cpu_average_percent cpu_peak_percent memory_average_mb memory_peak_mb average_fps]
statistics = {}
records.each do |row|
  puts "#{row[:project]}: #{row[:runs].length} XCTest run(s)"
  values = row[:runs].flat_map { |run| Array(run['sdkMetrics']) }
  statistics[row[:project]] = {}
  metrics.each do |metric|
    samples = values.filter_map { |item| item[metric] }.map(&:to_f).sort
    next if samples.empty?
    median = samples.length.odd? ? samples[samples.length / 2] : (samples[samples.length / 2 - 1] + samples[samples.length / 2]) / 2.0
    p95 = samples[[(samples.length * 0.95).ceil - 1, 0].max]
    mean = samples.sum / samples.length
    variance = samples.sum { |value| (value - mean)**2 } / samples.length
    statistics[row[:project]][metric] = { count: samples.length, average: mean, median: median, min: samples.first, max: samples.last, p95: p95, standard_deviation: Math.sqrt(variance) }
    puts "  #{metric}: n=#{samples.length} average=#{mean.round(3)} median=#{median.round(3)} min=#{samples.first.round(3)} max=#{samples.last.round(3)} p95=#{p95.round(3)} sd=#{Math.sqrt(variance).round(3)}"
  end
end
records.each do |row|
  xctest = row[:runs].flat_map { |run| Array(run['xctestMetrics']) }
  next if xctest.empty?
  puts "#{row[:project]} XCTest metrics:"
  xctest.group_by { |metric| [metric['identifier'] || metric['name'], metric['unit']] }.each do |(name, unit), entries|
    samples = entries.flat_map { |entry| Array(entry['measurements']) }.select { |value| value.is_a?(Numeric) }.map(&:to_f).sort
    next if samples.empty?
    median = samples.length.odd? ? samples[samples.length / 2] : (samples[samples.length / 2 - 1] + samples[samples.length / 2]) / 2.0
    p95 = samples[[(samples.length * 0.95).ceil - 1, 0].max]
    mean = samples.sum / samples.length
    variance = samples.sum { |value| (value - mean)**2 } / samples.length
    puts "  #{name} (#{unit}): n=#{samples.length} average=#{mean.round(3)} median=#{median.round(3)} min=#{samples.first.round(3)} max=#{samples.last.round(3)} p95=#{p95.round(3)} sd=#{Math.sqrt(variance).round(3)}"
  end
end
if records.length > 1
  baseline = records.first[:project]
  puts "Difference from #{baseline} (median):"
  records.drop(1).each do |row|
    metrics.each do |metric|
      left = statistics.dig(baseline, metric, :median)
      right = statistics.dig(row[:project], metric, :median)
      next unless left && right && left != 0
      percent = (right - left) / left * 100
      puts "  #{row[:project]} #{metric}: #{percent >= 0 ? '+' : ''}#{percent.round(2)}%"
    end
  end
end
report[:statistics] = statistics
File.write(File.join(comparison_dir, 'comparison.json'), JSON.pretty_generate(report) + "\n")
puts "Saved: #{File.join(comparison_dir, 'comparison.json')}"
