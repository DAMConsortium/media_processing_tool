# THIS CLASS IS CURRENTLY JUST A PASSTHROUGH TO THE GENERIC PUBLISH MAP PROCESSOR

require 'logger'
require 'udam_utils/publish_map_processor'
module MediaProcessingTool

  class Publisher

    attr_accessor :logger, :object, :publisher

    # @param [Hash] params
    # @option params [Object|nil] :logger
    # @Option params [String] :config_file_path
    def initialize(params = {})
      @logger = params[:logger] ||= Logger.new(STDOUT)

      @interrupted = false
      Signal.trap 'INT' do stop end
      Signal.trap 'TERM' do stop end
      Signal.trap 'SIGINT' do stop end

      #@config_file_path = params[:config_file_path]
      #raise ArgumentError, 'Missing required parameter :config_file_path' unless @config_file_path
      #load_configuration_from_file(@config_file_path)


      publisher_options = params
      @publisher = UDAMUtils::GenericPublishMapProcessor.new(publisher_options)

    end # initialize

    def stop
      @interrupted = true
      puts 'Quitting on interrupt signal.'
      while true
        puts 'Exiting...'
        exit
      end
    end # stop

    def publish(object, params = {})
      @object = object
    end # publish

  end # Publisher

end # MediaProcessingTool