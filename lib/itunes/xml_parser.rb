require 'cgi'
require 'plist'
require 'uri'
module ITunes

  class XMLParser

    def self.parse(xml, params = {})
      new(params.merge(file: xml))
    end # self.parse

    attr_reader :parsed

    def initialize(params = {})
      @file_name = params[:file]
      parse if @file_name
    end # initialize

    def parse(params = {})
      @parsed = Plist.parse_xml(@file_name)
    end # parse

    def tracks
      @tracks ||= parsed['Tracks']
    end # tracks

    def files
      @files ||= begin
        _files = [ ]
        tracks.each do |id, track|
          _files << track.merge(path_on_file_system: CGI.unescape(URI(track['Location']).path))
        end
        _files
      end
    end # files

    # Performs additional processing to each tracks fields
    # @param [Hash] _tracks
    def process_tracks(_tracks = @tracks)
      _tracks.dup.each do |id, track|
        add_path_to_track(id, track)
      end
    end # process_tracks

    def add_path_to_track(id, track)
      tracks[id]['Path'] = CGI.unescape(URI.parse(track['Location']).path)
    end # add_path_to_track

  end # XMLParser

end # ITunes