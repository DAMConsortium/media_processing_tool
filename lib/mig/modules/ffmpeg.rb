require 'open3'
require 'shellwords'
require 'time' # unless defined? Time

class FFMPEG

  DEFAULT_EXECUTABLE_PATH = 'ffmpeg'

  class Movie
    attr_reader :command, :output,
                :path, :duration, :time, :bitrate, :rotation, :creation_time,
                :video_stream, :video_codec, :video_bitrate, :colorspace, :resolution,
                :dar, :display_aspect_ratio,
                :sar, :storage_aspect_ratio,
                :par, :pixel_aspect_ratio,
                :width, :height, :is_widescreen, :is_high_definition, :calculated_aspect_ratio,
                :audio_stream, :audio_codec, :audio_bitrate, :audio_sample_rate
    
    def initialize(path, options = { })
      raise Errno::ENOENT, "No such file or directory - '#{path}'" unless File.exists?(path)
      @path = path
      
      #@logger = options.fetch(:logger, Logger.new(STDOUT)) 
      @ffmpeg_cmd_path = options.fetch(:ffmpeg_cmd_path, FFMPEG::DEFAULT_EXECUTABLE_PATH)
      

      # ffmpeg will output to stderr
      @command = [@ffmpeg_cmd_path, '-i', path].shelljoin
      #@logger.debug { "[FFMPEG] Executing command '#{command}'" }
      @output = Open3.popen3(command) { |stdin, stdout, stderr| stderr.read }
      #@logger.debug { "[FFMPEG] Command response: #{@output}" }
      
      fix_encoding(@output)
      
      @output[/Duration: (\d{2}):(\d{2}):(\d{2}\.\d{2})/]
      @duration = ($1.to_i*60*60) + ($2.to_i*60) + $3.to_f
      
      @output[/start: (\d*\.\d*)/]
      @time = $1 ? $1.to_f : 0.0

      @output[/creation_time {1,}: {1,}(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})/]
      @creation_time = $1 ? Time.parse("#{$1}") : nil
      
      @output[/bitrate: (\d*)/]
      @bitrate = $1 ? $1.to_i : nil
      
      @output[/rotate\ {1,}:\ {1,}(\d*)/]
      @rotation = $1 ? $1.to_i : nil

      @output[/Video: (.*)/]
      @video_stream = $1
      
      @output[/Audio: (.*)/]
      @audio_stream = $1
      
      @output[/timecode .* : (.*)/]
      @timecode = $1
      
      if video_stream
        # Example Strings
        #
        #  "dvvideo (dvc  / 0x20637664), 720x480, 28771 kb/s): unspecified pixel format"
        #  "mpeg2video (4:2:2) (mx5n / 0x6E35786D), yuv422p, 720x512 [SAR 512:405 DAR 16:9], 50084 kb/s, SAR 40:33 DAR 75:44, 29.97 fps, 29.97 tbr, 2997 tbn, 59.94 tbc"
        #  "h264 (Main) (avc1 / 0x31637661), yuv420p, 854x480 [SAR 1:1 DAR 427:240], 2196 kb/s, 29.97 fps, 29.97 tbr, 2997 tbn, 59.94 tbc"
        #  "prores (apcn / 0x6E637061), yuv422p10le, 720x486, 23587 kb/s, SAR 10:11 DAR 400:297, 29.97 fps, 29.97 tbr, 2997 tbn, 2997 tbc"

        if video_stream.end_with?('unspecified pixel format')
          @video_codec, @resolution, video_bitrate = video_stream.split(':').first.split(/\s?,\s?/)
          video_bitrate = video_bitrate[0..-2] if video_bitrate and video_bitrate.end_with?(')')
        else
          @video_codec, @colorspace, @resolution, video_bitrate, aspect_ratios = video_stream.split(/\s?,\s?/)
        end


        @video_bitrate = video_bitrate =~ %r(\A(\d+) kb/s\Z) ? $1.to_i : nil


        process_aspect_ratios(aspect_ratios) if aspect_ratios and aspect_ratios.include?(':')

        @resolution, aspect_ratios = @resolution.strip.split(' ', 2) rescue @resolution = aspect_ratios = nil

        process_aspect_ratios(aspect_ratios) if aspect_ratios and aspect_ratios.include?(':')

        @width, @height = @resolution.split('x') rescue @width = @height = nil
        @frame_rate = $1 if video_stream[/(\d*\.?\d*)\s?fps/]

        is_widescreen?
        
        is_high_definition?
      end
      
      if audio_stream
        @audio_codec, audio_sample_rate, @audio_channels, unused, audio_bitrate = audio_stream.split(/\s?,\s?/)
        @audio_bitrate = audio_bitrate =~ %r(\A(\d+) kb/s\Z) ? $1.to_i : nil
        @audio_sample_rate = audio_sample_rate[/\d*/].to_i
      end
      
      @invalid = true if @video_stream.to_s.empty? && @audio_stream.to_s.empty?
      @invalid = true if @output.include?('is not supported')
      @invalid = true if @output.include?('could not find codec parameters')
    end # initialize

    def process_aspect_ratios(aspect_ratios)
      @dar = @display_aspect_ratio = $1 if aspect_ratios[/DAR (\d+:\d+)/] rescue nil # Display Aspect Ratio = SAR * PAR
      @sar = @storage_aspect_ratio = $1 if aspect_ratios[/SAR (\d+:\d+)/] rescue nil # Storage Aspect Ratio = DAR/PAR
      @par = @pixel_aspect_ratio   = $1 if aspect_ratios[/PAR (\d+:\d+)/] rescue nil # Pixel aspect ratio = DAR/SAR
    end # process_aspect_ratios

    # @return [Boolean]
    def valid?
      not @invalid
    end
    
    # Determines if the aspect from dimensions is widescreen (> 1.5 (3/2)
    # 1.55 is derived from the following tables
    #   {http://en.wikipedia.org/wiki/Storage_Aspect_Ratio#Previous_and_currently_used_aspect_ratios Aspect Ratios}
    #   {http://en.wikipedia.org/wiki/List_of_common_resolutions#Television}
    #
    # 1.55:1 (14:9): Widescreen aspect ratio sometimes used in shooting commercials etc. as a compromise format
    # between 4:3 (12:9) and 16:9. When converted to a 16:9 frame, there is slight pillarboxing, while conversion to
    # 4:3 creates slight letterboxing. All widescreen content on ABC Family's SD feed is presented in this ratio.
    #
    # @return [Boolean]
    def is_widescreen?
      @is_widescreen ||= (aspect_from_dimensions ? (aspect_from_dimensions >= 1.55) : false)
    end
    alias :is_wide_screen :is_widescreen
    
    # (@link http://en.wikipedia.osrg/wiki/List_of_common_resolution)
    #
    # Lowest Width High Resolution Format Found:
    #   Panasonic DVCPRO100 for 50/60Hz over 720p - SMPTE Resolution = 960x720
    #
    # @return [Boolean]
    def is_high_definition?
      @is_high_definition ||= ( (width.respond_to?(:to_i) and height.respond_to?(:to_i)) ? (@width.to_i >= 950 and @height.to_i >= 700) : false )
    end
    alias :is_high_def? :is_high_definition?

    # Will attempt to
    def calculated_aspect_ratio
      @calculated_aspect_ratio ||= aspect_from_dar || aspect_from_dimensions
    end
    
    # @return [Integer] File Size
    def size
      @size ||= File.size(@path)
    end
    
    # @return [Integer]
    def audio_channel_count(audio_channels = @audio_channels)
      return 0 unless audio_channels
      return 1 if audio_channels['mono']
      return 2 if audio_channels['stereo']
      return 6 if audio_channels['5.1']
      return 9 if audio_channels['7.2']
      
      # If we didn't hit a match above then find any number in #.# format and add them together to get a channel count
      audio_channels[/(\d+.?\d?).*/]
      audio_channels = $1.to_s.split('.').map(&:to_i).inject(:+) if $1 rescue audio_channels 
      return audio_channels if audio_channels.is_a? Integer 
    end
    
    # Outputs relavant instance variables names and values as a hash
    # @return [Hash]
    def to_hash
      hash = Hash.new
      variables = instance_variables
      [ :@ffmpeg_cmd_path, :@logger ].each { |cmd| variables.delete(cmd) }
      variables.each { |instance_variable_name| 
        hash[instance_variable_name.to_s[1..-1]] = instance_variable_get(instance_variable_name)
      }
      hash['audio_channel_count'] = audio_channel_count
      hash['calculated_aspect_ratio'] = calculated_aspect_ratio
      hash
    end
    
    protected
    # @return [Integer|nil]
    def aspect_from_dar
      return nil unless dar
      return @aspect_from_dar if @aspect_from_dar
      w, h = dar.split(':')
      aspect = w.to_f / h.to_f
      @aspect_from_dar = aspect.zero? ? nil : aspect
    end
    
    # @return [Fixed]
    def aspect_from_dimensions
      return @aspect_from_dimensions if @aspect_from_dimensions
      
      aspect = width.to_f / height.to_f
      @aspect_from_dimensions = aspect.nan? ? nil : aspect
    end
    
    # @param [String] output
    def fix_encoding(output)
      output[/test/] # Running a regexp on the string throws error if it's not UTF-8
    rescue ArgumentError
      output.force_encoding('ISO-8859-1')
    end
  end
  
  # @param [Hash] options
  # @option options [String] :ffmpeg_cmd_path
  def initialize(options = { })
    @ffmpeg_cmd_path = options.fetch(:ffmpeg_cmd_path, 'ffmpeg')
  end # initialize
  
  # @param [String] file_path
  # @param [Hash] options
  # @option options [String] :ffmpeg_cmd_path  
  def run(file_path, options = { })
    options = { ffmpeg_cmd_path: @ffmpeg_cmd_path }.merge(options)
    Movie.new(file_path, options).to_hash
  end # run

end # FFMPEG