require 'benchmark' unless defined?(Benchmark)
require 'fileutils' unless defined?(FileUtils)
require 'json' unless defined?(JSON)
require 'tempfile' unless defined?(Tempfile)
require 'yaml'
require 'mixlib/shellout' unless defined?(Mixlib::ShellOut)

MEGABYTE = 1024.0 * 1024.0

module Common
  def banner(msg)
    puts "==> #{msg}"
  end

  def info(msg)
    puts "    #{msg}"
  end

  def shellout(cmd)
    info "Shelling out to run #{cmd}"
    sout = Mixlib::ShellOut.new(cmd)
    sout.live_stream = STDOUT
    sout.run_command
    sout.error! # fail hard if the cmd fails
  end

  def warn(msg)
    puts ">>> #{msg}"
  end

  #
  # Shellout to vagrant CLI to see if we're logged into the cloud
  #
  # @return [Boolean]
  #
  def logged_in?
    # rubocop:disable Modernize/ShellOutHelper
    shellout = Mixlib::ShellOut.new('vagrant cloud auth whoami').run_command
    # rubocop:enable Modernize/ShellOutHelper

    if shellout.error?
      error_output = !shellout.stderr.empty? ? shellout.stderr : shellout.stdout
      warn("Failed to shellout to vagrant to check the login status. Error: #{error_output}")
      return false
    end

    return true if shellout.stdout.match?(/Currently logged in/)

    false
  end

  def duration(total)
    total = 0 if total.nil?
    minutes = (total / 60).to_i
    seconds = (total - (minutes * 60))
    format('%dm%.2fs', minutes, seconds)
  end

  def box_metadata(metadata_file)
    metadata = {}
    file = File.read(metadata_file)
    json = JSON.parse(file)

    # metadata needed for upload: boxname, version, provider, box filename
    metadata['name'] = json['name']
    metadata['version'] = json['version']
    metadata['arch'] = json['arch']
    metadata['box_basename'] = json['box_basename']
    metadata['packer'] = json['packer']
    metadata['vagrant'] = json['vagrant']
    metadata['providers'] = {}
    json['providers'].each do |provider|
      metadata['providers'][provider['name']] = provider.reject { |k, _| k == 'name' }
    end
    metadata
  end

  def metadata_files(arch_support = false)
    arch = if RbConfig::CONFIG['host_cpu'] == 'arm64'
             'aarch64'
           else
             RbConfig::CONFIG['host_cpu']
           end
    glob = "builds/*#{"-#{arch}" if arch_support}._metadata.json"
    @metadata_files ||= Dir.glob(glob)
  end

  def builds_yml
    YAML.load(File.read('builds.yml'))
  end

  def private_box?(boxname)
    proprietary_os_list = %w(macos windows sles solaris rhel)
    proprietary_os_list.any? { |p| boxname.include?(p) }
  end

  def macos?
    !!(RUBY_PLATFORM =~ /darwin/)
  end

  def unix?
    !windows?
  end

  def windows?
    !!(RUBY_PLATFORM =~ /mswin|mingw|windows/)
  end
end
