require 'filemagic/ext'

class MediaType
  
  # @params [Hash] options Not currently used
  def initialize(options = {}); end # initialize
  
  # @params [String] file_path The path to the file to scan
  # @params [Hash] options Not currently used
  # @return [Hash] Will contain :type, :subtype and any other attributes output during the call 
  def run(file_path, options = { })
      media_type, charset = (File.mime_type(file_path) || '').split(';')
      type, subtype = media_type.split('/') if media_type.is_a?(String)
      output = { :type => type, :subtype => subtype }

      param = charset.strip.split('=') if charset.is_a?(String)
      output[param.first] = param.last if param.is_a?(Array)

      output
  end # run

end # MediaType
