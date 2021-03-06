require 'time'

class MediaInformationGatherer

  class Common

    STANDARD_VIDEO_FRAME_RATES = [ 23.97, 23.976, 24.0, 24.97, 24.975, 25.0, 29.97, 30.0, 50.0, 59.94, 60.0 ]

    def self.common_variables(metadata_sources)
      new.common_variables(metadata_sources)
    end

    def metadata_sources; @metadata_sources || { } end
    def ffmpeg; @ffmpeg ||= metadata_sources[:ffmpeg] || { } end
    def mediainfo; @mediainfo ||= metadata_sources[:mediainfo] || { 'section_type_count' => { 'audio' => 0 } } end
    def stat; @stat ||= metadata_sources[:stat] || { } end
    def cv; @cv ||= { } end

    def common_variables(_metadata_sources)
      @metadata_sources = _metadata_sources.dup
      @cv = { }

      file_path = ffmpeg['path']
      source_directory = file_path ? File.dirname(File.expand_path(file_path)) : ''
      creation_date_time = Time.parse(ffmpeg['creation_time']).strftime('%B %d, %Y %r') rescue ffmpeg['creation_time']

      cv[:file_path] = file_path
      cv[:source_directory] = source_directory
      cv[:creation_date_time] = creation_date_time
      cv[:ctime] = stat[:ctime]
      cv[:mtime] = stat[:mtime]
      cv[:bytes] = stat[:size]
      cv[:size] = (mediainfo['General'] || { })['File size']
      cv[:uid] = stat[:uid]
      cv[:gid] = stat[:gid]
      cv[:ftype] = stat[:ftype]

      type = :video # Need to figure out where to determine the type from
      case type #.to_s.downcase.to_sym
        when :video
          common_audio_variables
          common_video_variables
        when :audio
          common_audio_variables
        when :image
          common_image_variables
        else
          # What else is there?
      end
      if RUBY_VERSION.start_with?('1.8.')
        Hash[cv.map { |a| [ a[0].to_s, a[1] ] }.sort.map { |a| [ a[0].to_sym, a[1] ] }]
      else
        Hash[cv.sort]
      end
    end # common_variables

    def common_audio_variables
      mi_audio = mediainfo['Audio'] || { }
      mi_audio = { } unless mi_audio.is_a?(Hash)

      duration = ffmpeg['duration']
      if duration
        dl = duration
        dlh = dl / 3600
        dl %= 3600
        dlm = dl / 60
        dl %= 60
        duration_long = sprintf('%02d:%02d:%02d', dlh, dlm, dl)
      else
        duration_long = '00:00:00'
      end
      section_type_counts = mediainfo['section_type_counts'] || { }
      audio_track_count = section_type_counts['audio']

      cv[:audio_codec_id] = mi_audio['Codec ID']
      cv[:audio_sample_rate] = ffmpeg['audio_sample_rate']
      cv[:duration] = duration
      cv[:duration_long] = duration_long
      cv[:number_of_audio_tracks] = audio_track_count # Determine the number of audio channels
      cv[:number_of_audio_channels] = ffmpeg['audio_channel_count']

    end # common_audio_variables

    # @return [Fixed]
    def aspect_from_dimensions(height, width)
      aspect = width.to_f / height.to_f
      aspect.nan? ? nil : aspect
    end

    # Determines if the aspect from dimensions is widescreen (>= 1.5 (3/2)
    # 1.55 is derived from the following tables
    #   {http://en.wikipedia.org/wiki/Storage_Aspect_Ratio#Previous_and_currently_used_aspect_ratios Aspect Ratios}
    #   {http://en.wikipedia.org/wiki/List_of_common_resolutions#Television}
    #
    # 1.55:1 (14:9): Widescreen aspect ratio sometimes used in shooting commercials etc. as a compromise format
    # between 4:3 (12:9) and 16:9. When converted to a 16:9 frame, there is slight pillarboxing, while conversion to
    # 4:3 creates slight letterboxing. All widescreen content on ABC Family's SD feed is presented in this ratio.
    #
    # @return [Boolean]
    def is_widescreen?(height, width)
      _aspect_from_dimensions = aspect_from_dimensions(height, width)
      (_aspect_from_dimensions ? (_aspect_from_dimensions >= 1.55) : false)
    end

    # (@link http://en.wikipedia.osrg/wiki/List_of_common_resolution)
    #
    # Lowest Width High Resolution Format Found:
    #   Panasonic DVCPRO100 for 50/60Hz over 720p - SMPTE Resolution = 960x720
    #
    # @return [Boolean]
    def is_high_definition?(height, width)
      (width.respond_to?(:to_i) and height.respond_to?(:to_i)) ? (width.to_i >= 950 and height.to_i >= 700) : false
    end


    def common_image_variables

    end # common_image_variables

    def common_video_variables
      mi_video = mediainfo['Video'] || { }
      #return unless ffmpeg['video_stream'] or !mi_video.empty?

      frame_rate = ffmpeg['frame_rate']
      frame_rate ||= mi_video['Frame rate'].respond_to?(:to_f) ? mi_video['Frame rate'].to_f : mi_video['Frame rate']

      height = ffmpeg['height'] || mi_video['Height']
      width = ffmpeg['width'] || mi_video['Width']

      is_widescreen = ffmpeg['is_widescreen']
      is_widescreen ||= is_widescreen?(height, width) if is_widescreen.nil?

      is_high_definition = is_high_definition?(height, width)

      calculated_aspect_ratio = ffmpeg['calculated_aspect_ratio'] || (height.respond_to?(:to_f) and width.respond_to?(:to_f) ? (width.to_f / height.to_f) : nil)

      video_codec_id = mi_video['Codec ID']
      video_codec_description = video_codec_descriptions.fetch(video_codec_id, 'Unknown')

      video_system = determine_video_system(height, width, frame_rate)

      #aspect_ratio = ffmpeg['video_stream'] ? (ffmpeg['is_widescreen'] ? '16:9' : '4:3') : nil
      if ffmpeg['video_stream']
        aspect_ratio = ffmpeg['is_widescreen'] ? '16:9' : '4:3'
      else
        aspect_ratio = nil
      end

      cv[:aspect_ratio] = aspect_ratio
      cv[:bit_depth] = mi_video['Bit depth']
      cv[:calculated_aspect_ratio] = calculated_aspect_ratio
      cv[:chroma_subsampling] = mi_video['Chroma subsampling']
      cv[:display_aspect_ratio] = ffmpeg['display_aspect_ratio']
      cv[:frames_per_second] = frame_rate # Video frames per second
      cv[:height] = height
      cv[:is_high_definition] = is_high_definition # Determine if video is Standard Def or High Definition
      cv[:is_widescreen] = is_widescreen
      cv[:pixel_aspect_ratio] = ffmpeg['pixel_aspect_ratio']
      cv[:resolution] = ffmpeg['resolution']
      cv[:scan_order] = mi_video['Scan order']
      cv[:scan_type] = mi_video['Scan type']
      cv[:storage_aspect_ratio] = ffmpeg['storage_aspect_ratio']
      cv[:timecode] = ffmpeg['timecode']
      cv[:video_codec_id] = video_codec_id
      cv[:video_codec_commercial_name] = mi_video['Commercial name']
      cv[:video_codec_description] = video_codec_description
      cv[:video_system] = video_system
      cv[:width] = width
      cv
    end # common_video_variables

    # A hash of fourcc codes
    # http://www.videolan.org/developers/vlc/src/misc/fourcc.c
    def fourcc_codes
      @fourcc_codes ||= {
          '2vuy' => 'Apple FCP Uncompressed 8-bit 4:2:2',
          'v210' => 'Apple FCP Uncompressed 10-bit 4:2:2',
          'apcn' => 'Apple ProRes Standard',
          'apch' => 'Apple ProRes High Quality (HQ)',
          'apcs' => 'Apple ProRes LT',
          'apco' => 'Apple ProRes Proxy',
          'ap4c' => 'Apple ProRes 4444',
          'ap4h' => 'Apple ProRes 4444',
          'xdv1' => 'XDCAM HD 720p30 35Mb/s',
          'xdv2' => 'XDCAM HD 1080i60 35Mb/s',
          'xdv3' => 'XDCAM HD 1080i50 35Mb/s',
          'xdv4' => 'XDCAM HD 720p24 35Mb/s',
          'xdv5' => 'XDCAM HD 720p25 35Mb/s',
          'xdv6' => 'XDCAM HD 1080p24 35Mb/s',
          'xdv7' => 'XDCAM HD 1080p25 35Mb/s',
          'xdv8' => 'XDCAM HD 1080p30 35Mb/s',
          'xdv9' => 'XDCAM HD 720p60 35Mb/s',
          'xdva' => 'XDCAM HD 720p50 35Mb/s',
          'xdhd' => 'XDCAM HD 540p',
          'xdh2' => 'XDCAM HD422 540p',
          'xdvb' => 'XDCAM EX 1080i60 50Mb/s CBR',
          'xdvc' => 'XDCAM EX 1080i50 50Mb/s CBR',
          'xdvd' => 'XDCAM EX 1080p24 50Mb/s CBR',
          'xdve' => 'XDCAM EX 1080p25 50Mb/s CBR',
          'xdvf' => 'XDCAM EX 1080p30 50Mb/s CBR',
          'xd54' => 'XDCAM HD422 720p24 50Mb/s CBR',
          'xd55' => 'XDCAM HD422 720p25 50Mb/s CBR',
          'xd59' => 'XDCAM HD422 720p60 50Mb/s CBR',
          'xd5a' => 'XDCAM HD422 720p50 50Mb/s CBR',
          'xd5b' => 'XDCAM HD422 1080i60 50Mb/s CBR',
          'xd5c' => 'XDCAM HD422 1080i50 50Mb/s CBR',
          'xd5d' => 'XDCAM HD422 1080p24 50Mb/s CBR',
          'xd5e' => 'XDCAM HD422 1080p25 50Mb/s CBR',
          'xd5f' => 'XDCAM HD422 1080p30 50Mb/s CBR',
          'dvh2' => 'DV Video 720p24',
          'dvh3' => 'DV Video 720p25',
          'dvh4' => 'DV Video 720p30',
          'dvcp' => 'DV Video PAL',
          'dvc'  => 'DV Video NTSC',
          'dvp'  => 'DV Video Pro',
          'dvpp' => 'DV Video Pro PAL',
          'dv50' => 'DV Video C Pro 50',
          'dv5p' => 'DV Video C Pro 50 PAL',
          'dv5n' => 'DV Video C Pro 50 NTSC',
          'dv1p' => 'DV Video C Pro 100 PAL',
          'dv1n' => 'DV Video C Pro 100 NTSC',
          'dvhp' => 'DV Video C Pro HD 720p',
          'dvh5' => 'DV Video C Pro HD 1080i50',
          'dvh6' => 'DV Video C Pro HD 1080i60',
          'AVdv' => 'AVID DV',
          'AVd1' => 'MPEG2 I',
          'mx5n' => 'MPEG2 IMX NTSC 625/60 50Mb/s (FCP)',
          'mx5p' => 'MPEG2 IMX PAL 525/50 50Mb/s (FCP',
          'mx4n' => 'MPEG2 IMX NTSC 625/60 40Mb/s (FCP)',
          'mx4p' => 'MPEG2 IMX PAL 525/50 40Mb/s (FCP',
          'mx3n' => 'MPEG2 IMX NTSC 625/60 30Mb/s (FCP)',
          'mx3p' => 'MPEG2 IMX PAL 525/50 30Mb/s (FCP)',
          'hdv1' => 'HDV 720p30',
          'hdv2' => 'HDV 1080i60',
          'hdv3' => 'HDV 1080i50',
          'hdv4' => 'HDV 720p24',
          'hdv5' => 'HDV 720p25',
          'hdv6' => 'HDV 1080p24',
          'hdv7' => 'HDV 1080p25',
          'hdv8' => 'HDV 1080p30',
          'hdv9' => 'HDV 720p60',
          'hdva' => 'HDV 720p50',
          'avc1' => 'AVC-Intra',
          'ai5p' => 'AVC-Intra  50M 720p25/50',
          'ai5q' => 'AVC-Intra  50M 1080p25/50',
          'ai52' => 'AVC-Intra  50M 1080p24/30',
          'ai53' => 'AVC-Intra  50M 1080i50',
          'ai55' => 'AVC-Intra  50M 1080i60',
          'ai56' => 'AVC-Intra 100M 720p24/30',
          'ai1p' => 'AVC-Intra 100M 720p25/50',
          'ai1q' => 'AVC-Intra 100M 1080p25/50',
          'ai12' => 'AVC-Intra 100M 1080p24/30',
          'ai13' => 'AVC-Intra 100M 1080i50',
          'ai15' => 'AVC-Intra 100M 1080i60',
          'ai16' => 'AVC-Intra 100M 1080i60',
          'mpgv' => 'MPEG-2',
          'mp1v' => 'MPEG-2',
          'mpeg' => 'MPEG-2',
          'mpg1' => 'MPEG-2',
          'mp2v' => 'MPEG-2',
          'MPEG' => 'MPEG-2',
          'mpg2' => 'MPEG-2',
          'MPG2' => 'MPEG-2',
          'H262' => 'MPEG-2',
          'mjpg' => 'Motion JPEG',
          'mJPG' => 'Motion JPEG',
          'mjpa' => 'Motion JPEG',
          'JPEG' => 'Motion JPEG',
          'AVRn' => 'Avid Motion JPEG',
          'AVRn' => 'Avid Motion JPEG',
          'AVDJ' => 'Avid Motion JPEG',
          'ADJV' => 'Avid Motion JPEG',
          'wvc1' => 'Microsoft VC-1',
          'vc-1' => 'Microsoft VC-1',
          'VC-1' => 'Microsoft VC-1',
          'jpeg' => 'Photo JPEG',
      }
    end # fourcc_codes

    def video_codec_descriptions
      @video_codec_descriptions ||= fourcc_codes.merge({
        27 => 'MPEG-TS',
      })
    end

    def determine_video_system(height, width, frame_rate)
      # http://en.wikipedia.org/wiki/Broadcast_television_system
      # http://en.wikipedia.org/wiki/Standard-definition_television#Resolution
      # http://en.wikipedia.org/wiki/Pixel_aspect_ratio
      # http://www.bambooav.com/ntsc-and-pal-video-standards.html
      # Programmer's Guide to Video Systems - http://lurkertech.com/lg/video-systems/#fields

      # PAL = 25fps Standard: 768x576  Widescreen: 1024x576
      # NTSC = 29.97fps Standard: 720x540  Widescreen: 854x480
      video_system = 'unknown'

      return video_system unless height and width and frame_rate

      frame_rate = frame_rate.to_f
      return video_system unless STANDARD_VIDEO_FRAME_RATES.include?(frame_rate)

      height = height.to_i
      width = width.to_i

      # The following case statement is based off of - http://images.apple.com/finalcutpro/docs/Apple_ProRes_White_Paper_October_2012.pdf
      case height
        when 480, 486, 512
          case width
            when 720, 848, 854
              video_system = 'NTSC'
          end
        when 576, 608
          case width
            when 720
              video_system = 'PAL'
          end
        when 720
          case width
            when 960, 1280
              video_system = 'HD'
          end
        when 1080
          case width
            when 1280, 1440, 1920
              video_system = 'HD'
          end
      end # case height
      video_system
    end # determine_video_system

  end # Common

end # MediaInformationGatherer
