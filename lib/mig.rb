require 'logger'
require 'mig/modules/exiftool'
require 'mig/modules/ffmpeg'
require 'mig/modules/mediainfo'
require 'mig/modules/media_type'
require 'mig/modules/common'

class MediaInformationGatherer

  attr_reader :log, :media_type, :metadata_sources

  # @param [Hash] options
  # @option options [String] :exiftool_cmd_path
  # @option options [String] :ffmpeg_cmd_path
  # @option options [String] :mediainfo_cmd_path
  def initialize(options = { })
    @options = { }
    @options.merge!(options)

    @log = $log if $log
    @log ||= options.fetch(:logger, false)
    @log ||= Logger.new(STDOUT)
    log.debug { "#{self.class.name} - Options loaded. #{@options}" }

    params = { }
    common_params = { logger: @log }
    params = common_params.merge({ exiftool_cmd_path: @options[:exiftool_cmd_path]}) if @options[:exiftool_cmd_path]
    @exiftool = ExifTool.new( params )
    params = { }
    params = common_params.merge({ ffmpeg_cmd_path: @options[:ffmpeg_cmd_path]}) if @options[:ffmpeg_cmd_path]
    @ffmpeg = FFMPEG.new( params )
    params = { }
    params = common_params.merge({ mediainfo_cmd_path: @options[:mediainfo_cmd_path]}) if @options[:mediainfo_cmd_path]
    @mediainfo = Mediainfo.new( params )

    @media_typer = MediaType.new( )

    @metadata_sources = { }
  end # initialize

  # @param [String] file_path The path to the file to gather information about
  def run(file_path)
    raise Errno::ENOENT, "File Not Found. File Path: '#{file_path}'" unless File.exist?(file_path)
    @metadata_sources = { }
    @media_type = { }

    gathering_start = Time.now
    log.debug { "Gathering metadata for file: #{file_path}"}
    @metadata_sources = run_modules(file_path)
    log.debug { "Metadata gathering completed. Took: #{Time.now - gathering_start} seconds" }

    @media_type = @metadata_sources[:filemagic]

    @metadata_sources
  end # run

  # @param [String] file_path The path of the file to gather information about
  # @return [Hash]
  def run_modules(file_path)
    metadata_sources = Hash.new

    log.debug { "Running Filemagic." }
    start = Time.now and metadata_sources[:filemagic] = @media_typer.run(file_path, @options) rescue { error: { message: $!.message, backtrace: $!.backtrace } }
    log.debug { "Filemagic took #{Time.now - start}" }

    log.debug { "Running MediaInfo." }
    start = Time.now and metadata_sources[:mediainfo] = @mediainfo.run(file_path, @options) rescue { error: { message: $!.message, backtrace: $!.backtrace } }
    log.debug { "MediaInfo took #{Time.now - start}" }

    log.debug { "Running FFMPEG." }
    start = Time.now and metadata_sources[:ffmpeg] = @ffmpeg.run(file_path, @options) rescue { error: { message: $!.message, backtrace: $!.backtrace } }
    log.debug { "FFMpeg took #{Time.now - start}" }

    log.debug { "Running ExifTool." }
    start = Time.now and metadata_sources[:exiftool] = @exiftool.run(file_path) rescue { error: { message: $!.message, backtrace: $!.backtrace } }
    log.debug { "ExifTool took #{Time.now - start}" }

    metadata_sources[:common] = Common.common_variables(metadata_sources)
    metadata_sources
  end # run_modules

end # MediaInformationGatherer
