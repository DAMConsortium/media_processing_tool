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

        # The following case statement is based off of - http://images.apple.com/finalcutpro/docs/Apple_ProRes_White_Paper_October_2012.pdf
        case height
        when 486
          case width
          when 720
            video_system = 'NTSC' if STANDARD_VIDEO_FRAME_RATES.include? frame_rate
          end
        when 576
          case width
          when 720
            video_system = 'PAL' if STANDARD_VIDEO_FRAME_RATES.include? frame_rate
          end
        when 720
          case width
          when 960, 1280
            video_system = 'HD'  if STANDARD_VIDEO_FRAME_RATES.include? frame_rate
          end
        when 1080
          case width
          when 1280, 1440, 1920
            video_system = 'HD' if STANDARD_VIDEO_FRAME_RATES.include? frame_rate
          end
        end # case height
        video_system
      end # determine_video_system

    end # << self

  end # Common

end # MediaInformationGatherer