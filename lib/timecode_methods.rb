module TimecodeMethods

    # @param [Integer] time_base
    # @param [Boolean] ntsc
    def convert_time_base(time_base, ntsc)
      fps = case time_base.to_f
              when 24; ntsc ? 23.976 : 24.0
              when 30; ntsc ? 29.97 : 30.0
              when 60; ntsc ? 59.94 : 60.0
              else; time_base.to_f
            end
      #puts "Time Base: #{time_base} NTSC: #{ntsc} FPS: #{fps}"
      fps
    end # convert_time_base

    def convert_frames_time_base(frames, time_base_from, time_base_to, ntsc_from = false, ntsc_to = false)
      fps_from = convert_time_base(time_base_from, ntsc_from)
      fps_to = convert_time_base(time_base_to, ntsc_to)
      return 0 unless fps_from and fps_from > 0 and fps_to and fps_to > 0
      frames *= (fps_to / fps_from)
    end

    def timecode_to_frames(timecode, fps = 25.0, drop_frame = false)
      return 0 unless timecode and fps and fps > 0
      hours, minutes, seconds, frames = timecode.split(':')
      frames = frames.to_i
      frames += seconds.to_i * fps
      frames += (minutes.to_i * 60) * fps
      frames += (hours.to_i * 3600) * fps

      frames
    end

    def frames_to_timecode(frames, frame_rate = 25.0, ntsc = false, drop_code_separator = ';')
      return '00:00:00:00' unless frames and frames > 0 and frame_rate and frame_rate > 0
      fps = convert_time_base(frame_rate, ntsc)
      return frames_to_drop_frame_timecode(frames, fps, drop_code_separator) if ntsc
      seconds = frames.to_f / fps.to_f
      remaining_frames = frames % fps

      hours = seconds / 3600
      seconds %= 3600

      minutes = seconds / 60
      seconds %= 60

      sprintf('%02d:%02d:%02d:%02d', hours, minutes, seconds, remaining_frames)
    end # frames_to_timecode

    def frames_to_drop_frame_timecode(frames, time_base, frame_separator = ';')
      time_base = time_base.round(0)
      frames = frames.to_i

      skipped_frames = frames / (time_base * 60)
      skipped_frames *= 2
      added_frames = frames / (time_base * 600) #60 * 10
      added_frames *= 2

      frames += skipped_frames
      frames -= added_frames

      sec_frames = time_base
      min_frames = 60 * sec_frames
      hour_frames = 60 * min_frames

      hour = frames / hour_frames
      frames %= hour_frames

      min = frames / min_frames
      frames %= min_frames

      sec = frames / sec_frames
      frames %= sec_frames

      # mystery off by 2 error
      frames += 2 if hour > 2

      drop = frames
      return sprintf('%02d:%02d:%02d%s%02d', hour, min, sec, frame_separator, drop)
    end # frames_to_drop_frame_timecode

end # Timecode