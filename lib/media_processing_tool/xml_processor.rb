require 'media_processing_tool/xml_parser'
require 'media_processing_tool/publisher'
require 'mig'
module MediaProcessingTool

  class XMLProcessor

    def self.process(xml, params = { })

    end # self.process

    DEFAULT_FILE_PATH_FIELD_NAME = :path_on_file_system

    attr_accessor :logger

    # @return [Boolean] determines if the files parsed from the XML should be sent to a publisher
    attr_accessor :publish

    def initialize(params = { })
      initialize_logger(params)

      @publish = params.fetch(:publish, true)
      @default_file_path_field_name = params[:@default_file_path_field_name] || DEFAULT_FILE_PATH_FIELD_NAME

      initialize_mig(params.dup)
      initialize_default_publisher(params.dup)
    end # initialize

    def initialize_logger(params = { })
      @logger = params[:logger] ||= Logger.new(params[:log_to] || STDOUT)
      logger.level = params[:log_level] if params[:log_level]
      params[:logger] = logger unless params[:logger]
    end # initialize_logger

    def initialize_mig(params = {})
      logger.debug { "Initializing Media Processing Tool. #{params}" }
      @mig = MediaInformationGatherer.new(params)
    end # initialize_mig

    def initialize_default_publisher(params = {})
      logger.debug { "Initializing Default Publisher. #{params}" }
      params[:file_path_field_name] = @default_file_path_field_name
      @default_publisher = MediaProcessingTool::Publisher.new(params)
    end # initialize_publisher

    def document
     @document
    end # document
    alias :doc :document

    def document_type
      @identifier_document.type
    end # document_type

    def publisher(params = {})
      @publisher
    end # publisher

    def process(xml, params = {})
      @document = XMLParser.parse(xml)
      @identifier_document = XMLParser.identifier_document
      @params = params

      @files = document.respond_to?(:files) ? document.files : [ ]
      @results = { }

      #force_default_publisher = params[:force_default_publisher]
      force_default_publisher = params.fetch(:force_default_publisher, true)

      if force_default_publisher
        @publisher = @default_publisher.dup
        @results[:files] = process_document_files(@files, :publisher => @publisher) if @files
      else
        # TODO PUT IN DYNAMIC PUBLISHER HANDLING
        doc_type = document_type
      end

      #{ :files => files, :sequences => sequences }

      @results
    end # process

    def process_document_files(_files, params = {})
      publisher = params[:publisher]

      run_mig = params.fetch(:run_mig, true)

      _results = [ ]
      total_files = _files.length
      current_file_counter = 0
      _files.each do |file|
        current_file_counter += 1
        full_file_path = file[@default_file_path_field_name]

        logger.debug { "Processing Document File #{current_file_counter} of #{total_files}. File Path: #{full_file_path}" }
        if run_mig
          _mig = run_mig_on_file(full_file_path)
          file[:metadata_sources] = _mig ? _mig.metadata_sources : { }
        else
          logger.debug { 'Media Information Gathering SKIPPED. run_mig set to false.' }
        end
        file_result = { file: file }
        file_result[:publish_result] = publisher.process(file) if publish and publisher

        _results << file_result
      end
      _results
    end # process_files

    def process_document_sequences(params = {})
      sequences = doc.respond_to?(:sequences) ? doc.sequences : [ ]
    end # process_sequences

    def process_document_tracks(params = {})
      tracks = doc.respond_to?(:tracks) ? doc.tracks : [ ]
    end # process_tracks

    def run_mig_on_file(full_file_path, params = {})
      if File.exists?(full_file_path)
        @mig.run(full_file_path)
        return @mig
      else
        logger.debug { "Media Information Gathering SKIPPED. File Not Found. #{full_file_path}" }
        return false
      end
    end # run_mig_on_file

  end # XMLProcessor
end # MediaProcessingTool