class MediaInformationGatherer

  class Common

    STANDARD_VIDEO_FRAME_RATES = [ 23.97, 23.976, 24.0, 24.97, 24.975, 25.0, 29.97, 30.0, 50.0, 60.0 ]
    class << self

      def common_variables(metadata_sources)
        type = :video # Need to figure out where to determine the type from
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

        frame_rate = ffmpeg['frame_rate']
        height = ffmpeg['height']
        width = ffmpeg['width']
        video_system = determine_video_system(height, width, frame_rate)

        cv[:aspect_ratio] = ffmpeg['is_widescreen'] ? '16:9' : '4:3'
        cv[:audio_sample_rate] = ffmpeg['audio_sample_rate']
        cv[:bit_depth] = mi_video['Bit depth']
        cv[:calculated_aspect_ratio] = ffmpeg['calculated_aspect_ratio']
        cv[:chroma_subsampling] = mi_video['Chroma subsampling']
        cv[:codec_id] = mediainfo['Codec ID']
        cv[:codec_commercial_name] = mediainfo['Commercial name']
        cv[:duration] = ffmpeg['duration']
        cv[:frames_per_second] = frame_rate # Video frames per second
        cv[:height] = height
        cv[:is_high_definition] = ffmpeg['is_high_definition'] # Determine if video is Standard Def or High Definition
        cv[:number_of_audio_tracks] = audio_track_count # Determine the number of audio channels
        cv[:number_of_audio_channels] = ffmpeg['audio_channel_count']
        cv[:resolution] = ffmpeg['resolution']
        cv[:scan_order] = mi_video['Scan order']
        cv[:scan_type] = mi_video['Scan type']
        cv[:timecode] = ffmpeg['timecode']
        cv[:video_system] = video_system
        cv[:width] = width
        cv
      end # common_video_variables

      def determine_video_system(height, width, frame_rate)
        # http://en.wikipedia.org/wiki/Broadcast_television_system
        # http://en.wikipedia.org/wiki/Standard-definition_television#Resolution
        # http://en.wikipedia.org/wiki/Pixel_aspect_ratio
        # http://www.bambooav.com/ntsc-and-pal-video-standards.html
        # Programmer's Guide to Video Systems - http://lurkertech.com/lg/video-systems/#fields

        video_system = 'unknown'
        return video_system unless height and width and frame_rate

        height = height.to_i
        width = width.to_i
        frame_rate = frame_rate.to_f

        dar = par = nil

        case height
          when 480, 486
            #480 height is the clean aperture height for a 480i video - http://lurkertech.com/lg/video-systems/#480i
            #video_format = '480i'
            case width
              when 320, 640
                dar = '4:3'
              #par = '10:11'
              when 427, 853
                dar = '16:9'
              #par = '40:33'
            end
            #video_system = 'NTSC' if frame_rate == 29.97 and dar
            video_system = 'NTSC' if dar and STANDARD_VIDEO_FRAME_RATES.include? frame_rate
          when 576
            #video_format = '576i'
            case width
              when 384, 385, 768, 769
                dar = '4:3'
              #par = '12:11'
              when 512, 513, 1024, 1026
                dar = '16:9'
              #par = '16:11'
            end
            #video_system = 'PAL' if frame_rate == 25 and dar
            video_system = 'PAL' if dar and STANDARD_VIDEO_FRAME_RATES.include? frame_rate
          when 702
            # 720i (Clean Aperture)
            case width
              when 1248
                #video_format = '720i'
                video_system = 'HD' if STANDARD_VIDEO_FRAME_RATES.include? frame_rate
            end
          when 720
            # 720i (Production Aperture)
            case width
              when 1280
                #video_format = '720i'
                video_system = 'HD'  if STANDARD_VIDEO_FRAME_RATES.include? frame_rate
            end
          when 1062
            # 1080i (Clean Aperture)
            case width
              when 1888
                #video_format = '1080i'
                video_system = 'HD' if STANDARD_VIDEO_FRAME_RATES.include? frame_rate
            end
          when 1080
            # 1080i (Production Aperture)
            case width
              when 1920
                #video_format = '1080i'
                dar = '16:9'
              #par = '4:3'
            end
            video_system = 'HD' if dar and STANDARD_VIDEO_FRAME_RATES.include? frame_rate
        end # case height
        video_system
      end # determine_video_system

    end # << self

  end # Common

end # MediaInformationGatherer