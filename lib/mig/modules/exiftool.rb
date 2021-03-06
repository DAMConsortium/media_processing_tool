require 'json'
require 'shellwords'
class MediaInformationGatherer

class ExifTool

  DEFAULT_EXECUTABLE_PATH = 'exiftool'

  def initialize(options = { })
    #@logger = options[:logger] || Logger.new(STDOUT)
    @exiftool_cmd_path = options.fetch(:exiftool_cmd_path, DEFAULT_EXECUTABLE_PATH)
  end # initialize
  
  # @param [String] file_path
  # @param [Hash] options
  def run(file_path, options = {})
    cmd_line = [@exiftool_cmd_path, '-json', file_path].shelljoin
    #@logger.debug { "[ExifTool] Executing command: #{cmd_line}" }
    metadata_json = %x(#{cmd_line})
    #@logger.debug { "[ExifTool] Result: #{metadata_json}" }
    JSON.parse(metadata_json)[0]
  end # self.run
  
end #ExifTool

end