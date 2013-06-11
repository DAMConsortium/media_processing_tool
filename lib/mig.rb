require 'logger'
require 'mig/modules/exiftool'
require 'mig/modules/ffmpeg'
require 'mig/modules/mediainfo'
require 'mig/modules/media_type'

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

    metadata_sources[:common] = common_variables(metadata_sources)
    metadata_sources
  end # run_modules

  def common_variables(metadata_sources)
    #TODO: Need to figure out what source to use to determine the media type
    type = :video

    cv = { }
    case type.downcase.to_sym
      when :video
        cv.merge!(common_video_variables(metadata_sources))
      when :audio
        cv.merge!(common_audio_variables(metadata_sources))
      when :image
        cv.merge!(common_image_variables(metadata_sources))
      else
        # What else is there?
    end
    cv
  end # common_variables

  def common_audio_variables(metadata_sources)

  end # common_audio_variables

  def common_image_variables(metadata_sources)

  end # common_image_variables

  def common_video_variables(metadata_sources)
    #puts metadata_sources
    cv = { }
    ffmpeg = metadata_sources[:ffmpeg] || { }
    mediainfo = metadata_sources[:mediainfo] || { 'section_type_count' => { 'audio' => 0 } }
    mi_video = mediainfo['video'] || { }

    section_type_counts = mediainfo['section_type_counts'] || { }
    audio_track_count = section_type_counts['audio']

    cv[:aspect_ratio] = ffmpeg['is_widescreen'] ? '16:9' : '4:3'
    cv[:audio_sample_rate] = ffmpeg['audio_sample_rate']
    cv[:bit_depth] = mi_video['Bit depth']
    cv[:calculated_aspect_ratio] = ffmpeg['calculated_aspect_ratio']
    cv[:chroma_subsampling] = mi_video['Chroma subsampling']
    cv[:codec_id] = mediainfo['Codec ID']
    cv[:codec_commercial_name] = mediainfo['Commercial name']
    cv[:duration] = ffmpeg['duration']
    cv[:frames_per_second] = ffmpeg['frame_rate'] # Video frames per second
    cv[:height] = ffmpeg['height']
    cv[:is_high_definition] = ffmpeg['is_high_definition'] # Determine if video is Standard Def or High Definition
    cv[:number_of_audio_tracks] = audio_track_count # Determine the number of audio channels
    cv[:number_of_audio_channels] = ffmpeg['audio_channel_count']
    cv[:resolution] = ffmpeg['resolution']
    cv[:scan_order] = mi_video['Scan order']
    cv[:scan_type] = mi_video['Scan type']
    cv[:timecode] = ffmpeg['timecode']
    cv[:width] = ffmpeg['width']
    cv
  end # common_video_variables

end # MediaInformationGatherer
