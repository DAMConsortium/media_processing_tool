require 'logger'
require 'mig/modules/exiftool'
require 'mig/modules/ffmpeg'
require 'mig/modules/mediainfo'
require 'mig/modules/media_type'
require 'mig/modules/common'

class MediaInformationGatherer

  File::Stat.class_eval do

    def to_hash
      (self.methods - Object.methods - [__callee__]).each_with_object({}) { |meth, acc| acc[meth] = self.send(meth) if self.method(meth).arity == 0 }
    end

  end

  attr_reader :log, :options

  # @param [Hash] _options
  # @option options [String] :exiftool_cmd_path
  # @option options [String] :ffmpeg_cmd_path
  # @option options [String] :mediainfo_cmd_path
  def initialize(_options = { })
    @options = { }
    @options.merge!(_options)

    @log = options[:logger] || $log || Logger.new(STDOUT)
    log.debug { "#{self.class.name} - Options loaded. #{options}" }

    options[:logger] ||= log

    params = options.dup

    @exiftool = ExifTool.new( params )
    @ffmpeg = FFMPEG.new( params )
    @mediainfo = Mediainfo.new( params )

    @media_typer = MediaType.new

  end # initialize

  def media_type; @media_type ||= { } end
  def metadata_sources; @metadata_sources ||= { } end

  # @param [String] file_path The path to the file to gather information about
  def run(file_path)
    @media_type = { }
    @metadata_sources = { }

    raise Errno::ENOENT, "File Not Found. File Path: '#{file_path}'" unless File.exist?(file_path)


    gathering_start = Time.now
    log.debug { "Gathering metadata for file: #{file_path}"}
    @metadata_sources = run_modules(file_path)
    log.debug { "Metadata gathering completed. Took: #{Time.now - gathering_start} seconds" }

    metadata_sources
  end # run

  # @param [String] file_path The path of the file to gather information about
  # @return [Hash]
  def run_modules(file_path)
    log.debug { 'Running File Stat.' }
    start = Time.now and metadata_sources[:stat] = File.stat(file_path).to_hash rescue { :error => { :message => $!.message, :backtrace => $!.backtrace } }
    log.debug { "File Stat took #{Time.now - start}" }

    log.debug { 'Running Filemagic.' }
    start = Time.now and metadata_sources[:filemagic] = @media_typer.run(file_path, options) rescue { :error => { :message => $!.message, :backtrace => $!.backtrace } }
    log.debug { "Filemagic took #{Time.now - start}" }

    log.debug { 'Running MediaInfo.' }
    start = Time.now and metadata_sources[:mediainfo] = @mediainfo.run(file_path, options) rescue { :error => { :message => $!.message, :backtrace => $!.backtrace } }
    log.debug { "MediaInfo took #{Time.now - start}" }

    log.debug { 'Running FFMPEG.' }
    start = Time.now and metadata_sources[:ffmpeg] = @ffmpeg.run(file_path, options) rescue { :error => { :message => $!.message, :backtrace => $!.backtrace } }
    log.debug { "FFMpeg took #{Time.now - start}" }

    log.debug { 'Running ExifTool.' }
    start = Time.now and metadata_sources[:exiftool] = @exiftool.run(file_path) rescue { :error => { :message => $!.message, :backtrace => $!.backtrace } }
    log.debug { "ExifTool took #{Time.now - start}" }

    set_media_type
    metadata_sources[:media_type] = media_type

    metadata_sources[:common] = Common.common_variables(metadata_sources)

    metadata_sources
  end # run_modules

  def get_media_type_using_exiftool
    exiftool_md = metadata_sources[:exiftool]
    return unless exiftool_md.is_a?(Hash)

    mime_type = exiftool_md['MIMEType']
    return unless mime_type.is_a?(String)

    type, sub_type = mime_type.split('/')
    return unless type

    { :type => type, :subtype => sub_type }
  end

  def get_media_type_using_filemagic
    filemagic_md = metadata_sources[:filemagic]
    return unless filemagic_md.is_a?(Hash)
    return unless filemagic_md[:type]

    filemagic_md
  end

  def set_media_type
    @media_type = get_media_type_using_filemagic || get_media_type_using_exiftool
  end

end # MediaInformationGatherer
