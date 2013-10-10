module TimecodeMethods

    # @param [Integer] time_base
    # @param [Boolean] ntsc
    def self.convert_time_base(time_base, ntsc)
      fps = case time_base.to_f
              when 24; ntsc ? 23.976 : 24.0
              when 30; ntsc ? 29.97 : 30.0
              when 60; ntsc ? 59.94 : 60.0
              else; time_base.to_f
            end
      #puts "Time Base: #{time_base} NTSC: #{ntsc} FPS: #{fps}"
      fps
    end # convert_time_base
    def convert_time_base(*args); self.convert_time_base(*args) end

    def self.convert_frames_time_base(frames, frame_rate_from, frame_rate_to)
      return 0 unless frame_rate_from and frame_rate_from > 0 and frame_rate_to and frame_rate_to > 0
      frames * (frame_rate_to / frame_rate_from)
    end # convert_frames_time_base
    def convert_frames_time_base(*args); self.convert_frames_time_base(*args) end

    def self.timecode_to_frames(timecode, fps = 25.0, drop_frame = false)
      return 0 unless timecode and fps and fps > 0
      hours, minutes, seconds, frames = timecode.split(':')
      frames = frames.to_i
      frames += seconds.to_i * fps
      frames += (minutes.to_i * 60) * fps
      frames += (hours.to_i * 3600) * fps

      frames
    end # timecode_to_frames
    def timecode_to_frames(*args); self.timecode_to_frames(*args) end

    def self.frames_to_timecode(frames, frame_rate = 25.0, drop_frame = false, drop_code_separator = ';')
      return '00:00:00:00' unless frames and frames > 0 and frame_rate and frame_rate > 0
      return frames_to_drop_frame_timecode(frames, frame_rate, drop_code_separator) if drop_frame
      fps = frame_rate.to_f
      seconds = frames.to_f / fps
      remaining_frames = frames % fps

      hours = seconds / 3600
      seconds %= 3600

      minutes = seconds / 60
      seconds %= 60

      sprintf('%02d:%02d:%02d:%02d', hours, minutes, seconds, remaining_frames)
    end # frames_to_timecode
    def frames_to_timecode(*args); self.frames_to_timecode(*args) end

    def self.frames_to_drop_frame_timecode(frames, frame_rate, frame_separator = ';')
      # FIXME FAILS TESTS

      #?> frames_to_drop_frame_timecode(5395, 29.97)
      #=> "00:02:59;29"
      #frames_to_drop_frame_timecode(5396, 29.97)
      #=> "00:03:00;00"
      #?> frames_to_drop_frame_timecode(5397, 29.97)
      #=> "00:03:00;01"


      #?> frames_to_drop_frame_timecode(1800, 29.97)
      #=> "00:01:00;02"

      #?> frames_to_drop_frame_timecode(3600, 29.97)
      #=> "00:02:00;04"

      #?> frames_to_drop_frame_timecode(5400, 29.97)
      #=> "00:03:00;06"

      # when frames equals 1800 then timecode should be '00:01:00:00'
      # when frames equals 3600 then timecode should be '00:02:02:00'
      # when frames equals 5400 then timecode should be '00:03:02:00'
      # when frames equals 18000 then timecode should be 00:10:00:00'
      frame_rate = frame_rate.round(0)
      frames = frames.to_i

      skipped_frames = frames / (frame_rate * 60)
      skipped_frames *= 2
      added_frames = frames / (frame_rate * 600) #60 * 10
      added_frames *= 2

      frames += skipped_frames
      frames -= added_frames

      sec_frames = frame_rate
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
    def frames_to_drop_frame_timecode(*args); self.frames_to_drop_frame_timecode(*args) end

end # Timecode