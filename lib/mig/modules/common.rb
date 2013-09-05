require 'time'

class MediaInformationGatherer

  class Common

    STANDARD_VIDEO_FRAME_RATES = [ 23.97, 23.976, 24.0, 24.97, 24.975, 25.0, 29.97, 30.0, 50.0, 60.0 ]
    class << self

      def common_variables(metadata_sources)
        type = :video # Need to figure out where to determine the type from
        cv = { }
        case type.downcase.to_sym
          when :video
            _cv = common_video_variables(metadata_sources) rescue { }
            cv.merge!(_cv)
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
        mi_video = mediainfo['Video'] || { }
        mi_audio = mediainfo['Audio'] || { }

        creation_date_time = Time.parse(ffmpeg['creation_time']).strftime('%B %d, %Y %r') rescue ffmpeg['creation_time']

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

        frame_rate = ffmpeg['frame_rate']
        height = ffmpeg['height']
        width = ffmpeg['width']

        video_codec_id = mi_video['Codec ID']
        video_codec_description = fourcc_codes.fetch(video_codec_id, 'Unknown')

        video_system = determine_video_system(height, width, frame_rate)

        cv[:aspect_ratio] = ffmpeg['is_widescreen'] ? '16:9' : '4:3'
        cv[:audio_codec_id] = mi_audio['Codec ID']
        cv[:audio_sample_rate] = ffmpeg['audio_sample_rate']
        cv[:bit_depth] = mi_video['Bit depth']
        cv[:calculated_aspect_ratio] = ffmpeg['calculated_aspect_ratio']
        cv[:chroma_subsampling] = mi_video['Chroma subsampling']
        cv[:creation_date_time] = creation_date_time
        cv[:duration] = duration
        cv[:duration_long] = duration_long
        cv[:frames_per_second] = frame_rate # Video frames per second
        cv[:height] = height
        cv[:is_high_definition] = ffmpeg['is_high_definition'] # Determine if video is Standard Def or High Definition
        cv[:is_widescreen] = ffmpeg['is_widescreen']
        cv[:number_of_audio_tracks] = audio_track_count # Determine the number of audio channels
        cv[:number_of_audio_channels] = ffmpeg['audio_channel_count']
        cv[:resolution] = ffmpeg['resolution']
        cv[:scan_order] = mi_video['Scan order']
        cv[:scan_type] = mi_video['Scan type']
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
            'dvc ' => 'DV Video NTSC',
            'dvp ' => 'DV Video Pro',
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
            'mx5n' => 'MPEG2 IMX PAL 625/60 50Mb/s (FCP)"',
            'mx5p' => 'MPEG2 IMX NTSC 525/60 40Mb/s (FCP',
            'mx4n' => 'MPEG2 IMX PAL 625/50 40Mb/s (FCP)"',
            'mx4p' => 'MPEG2 IMX NTSC 525/60 30Mb/s (FCP',
            'mx3n' => 'MPEG2 IMX NTSC 625/50 30Mb/s (FCP)',
            'mx3p' => 'HDV 720p30 (MPEG-2 Video)"),',
            'hdv1' => 'Sony HDV 1080i60 (MPEG-2 ',
            'hdv2' => 'FCP HDV 1080i50 (MPEG-2 Video)"',
            'hdv3' => 'HDV 720p24 (MPEG-2 Video)"),',
            'hdv4' => 'HDV 720p25 (MPEG-2 Video)',
            'hdv5' => 'HDV 1080p24 (MPEG-2 Video',
            'hdv6' => 'HDV 1080p25 (MPEG-2 Video)',
            'hdv7' => 'HDV 1080p30 (MPEG-2 Video)',
            'hdv8' => 'HDV 720p60 JVC (MPEG-2 Vid',
            'hdv9' => 'HDV 720p50 (MPEG-2 Video)"),',
            'hdva' => 'AVC-Intra"),',
            'avc1' => 'AVC-Intra',
            'ai5p' => 'AVC-Intra  50M 720p25/50"),',
            'ai5q' => 'AVC-Intra  50M 1080p25/5',
            'ai52' => 'AVC-Intra  50M 1080p24/30',
            'ai53' => 'AVC-Intra  50M 1080i50"),',
            'ai55' => 'AVC-Intra  50M 1080i60',
            'ai56' => 'AVC-Intra 100M 720p24/',
            'ai1p' => 'AVC-Intra 100M 720p25/50"),',
            'ai1q' => 'AVC-Intra 100M 1080p25/5',
            'ai12' => 'AVC-Intra 100M 1080p24/30',
            'ai13' => 'AVC-Intra 100M 1080i50"),',
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
          when 480, 486
            case width
              when 720
                video_system = 'NTSC'
            end
          when 576
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

    end # << self

  end # Common

end # MediaInformationGatherer

