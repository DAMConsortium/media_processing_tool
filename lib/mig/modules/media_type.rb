require 'filemagic/ext'

class MediaType
  
  # @params [Hash] options Not currently used
  def initialize(options = {}); end # initialize
  
  # @params [String] file_path The path to the file to scan
  # @params [Hash] options Not currently used
  # @return [Hash] Will contain :type, :subtype and any other attributes output during the call 
  def run(file_path, options = { })
      media_type, charset = File.mime_type(file_path).split(';') rescue nil
      type, subtype = media_type.split('/')
      param = charset.split('=') rescue nil
      
      output = { type: type, subtype: subtype }
      output[param[0].strip] = param[1].strip rescue nil
      output
  end # run
  
end # MediaType