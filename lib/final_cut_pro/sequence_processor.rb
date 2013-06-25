require 'logger'
require 'uri'
require 'timecode_methods'

module FinalCutPro
  class SequenceProcessor

    class << self
      include TimecodeMethods

      attr_writer :logger
      def logger; @logger ||= Logger.new(STDOUT) end

      def parse_xml(xml)
        doc = FinalCutPro::XMLParser.load(xml)
        sequences = doc.parse_sequences(xml)
        process(sequences)
      end

      def process(sequences)
        files = { }
        clips = [ ]
        _sequences = { }
        [*sequences].each do |sequence|
          sequence_id = sequence[:id]
          clip_items = sequence[:clip_items]
          next unless clip_items
          clip_item_counter = 0
          clip_items_count = clip_items.count
          clip_items.each do |clip_item|
            clip_item_counter += 1
            #logger.debug { "Clip Item #{clip_item_counter} of #{clip_items_count}"}

            clip_rate = clip_item[:rate]
            clip_time_base = clip_rate[:timebase].to_f
            clip_rate_ntsc = clip_rate[:ntsc] == 'TRUE' ? true : false
            clip_frame_rate = convert_time_base(clip_time_base, clip_rate_ntsc)

            clip_duration_frames = clip_item[:duration].to_i
            clip_duration_seconds = clip_duration_frames / clip_frame_rate

            clip_start_frame = clip_item[:start].to_i
            clip_end_frame = clip_item[:end].to_i

            clip_in_frame = clip_item[:in].to_i
            clip_out_frame = clip_item[:out].to_i


            # File tags may just be a reference to an earlier file tag. A reference only includes an id attribute which we
            # can use to lookup the file from previous parsing.
            file = clip_item[:file] || { }
            if file.keys.count == 1
              # We only got the id with this file tag so look it up in our file cache
              file = files[file[:id]]
            else
              # This file has more than just an ID so it's not a reference to a previous file. Store it in the file cache
              files[file[:id]] = file
            end
            next unless file

            file_timecode = file[:timecode] || { }
            file_timecode_value = file_timecode[:string] || '00:00:00:00'
            file_timecode_frame = file_timecode[:frame].to_i

            file_rate = file[:rate] || { }
            file_time_base = file_rate[:timebase]
            file_rate_ntsc = (file_rate[:ntsc] == 'TRUE') ? true : false
            file_frame_rate = convert_time_base(file_time_base, file_rate_ntsc)
            #puts "TB: #{file_time_base} NTSC: #{file_rate_ntsc} FPS: #{file_frame_rate}"
            file_in_frame = clip_in_frame # + file_timecode_frame
            file_out_frame = clip_out_frame # + file_timecode_frame

            file_in_frame_at_clip_frame_rate = clip_in_frame * (file_frame_rate / clip_frame_rate)
            file_out_frame_at_clip_frame_rate = clip_out_frame * (file_frame_rate / clip_frame_rate)

            file_in_timecode = frames_to_timecode(file_in_frame, clip_frame_rate, clip_rate_ntsc, ':')
            file_out_timecode = frames_to_timecode(file_out_frame, clip_frame_rate, clip_rate_ntsc, ':')

            #file_in_timecode_with_offset = TimecodeHelper.timecode_calculator(file_in_timecode, file_out_timecode, file_timecode_value, file_frame_rate)
            file_in_seconds = (file_in_frame/clip_frame_rate) # TimecodeHelper.convert_frames_to_seconds(file_frame_rate, file_in_frame)
            file_out_seconds = (file_out_frame/clip_frame_rate) # TimecodeHelper.convert_frames_to_seconds(file_frame_rate, file_out_frame)

            file_path_url = file[:pathurl] || ''
            file_path = URI.unescape(file_path_url).scan(/.*:\/\/\w*(\/.*)/).flatten.first

            file_in_frame_with_offset = file_timecode_frame + (file_in_frame * (file_frame_rate / clip_frame_rate))
            file_out_frame_with_offset = file_timecode_frame + (file_out_frame * (file_frame_rate / clip_frame_rate))
            file_in_timecode_with_offset = frames_to_timecode(file_in_frame_with_offset, file_frame_rate, file_rate_ntsc, ';')
            file_out_timecode_with_offset = frames_to_timecode(file_out_frame_with_offset, file_frame_rate, file_rate_ntsc, ';')

            clips << {
              :start_frame => clip_start_frame,
              :end_frame => clip_end_frame,
              :timebase => clip_time_base,
              :ntsc => clip_rate[:ntsc],
              :frame_rate => clip_frame_rate,
              :sequence => { :id => sequence_id },
              :file => {
                :pathurl => file_path_url,
                :path => file_path,
                :timecode => file_timecode,
                :timebase => file_time_base,
                :ntsc => file_rate_ntsc,
                :frame_rate => file_frame_rate,

                :in_frame => file_in_frame,
                :out_frame => file_out_frame,
                :in_seconds => file_in_seconds,
                :out_seconds => file_out_seconds,
                :in_frame_with_offset => file_in_frame_with_offset,
                :out_frame_with_offset => file_out_frame_with_offset,
                :in_timecode_with_offset => file_in_timecode_with_offset,
                :out_timecode_with_offset => file_out_timecode_with_offset,
              },
            }
            _sequences[sequence_id] = clips
          end
        end
        _sequences
      end # process

    end # << self

  end # SequenceProcessor
end # FinalCutPro