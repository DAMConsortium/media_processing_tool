require 'media_processing_tool/xml_parser'
require 'media_processing_tool/publisher'
require 'mig'
module MediaProcessingTool
  class XMLProcessor

    def self.process(xml, params = { })

    end # self.process

    DEFAULT_FILE_PATH_FIELD_NAME = :path_on_file_system

    attr_accessor :logger
    def initialize(params = { })
      @logger = params[:logger] ||= Logger.new(params[:log_to] || STDOUT)
      logger.level = params[:log_level] if params[:log_level]
      params[:logger] = logger unless params[:logger]

      initialize_mig(params.dup)
      initialize_default_publisher(params.dup)
    end # initialize

    def initialize_mig(params = {})
      logger.debug { "Initializing Media Processing Tool. #{params}" }
      @mig = MediaInformationGatherer.new(params)
    end # initialize_mig

    def initialize_default_publisher(params = {})
      logger.debug { "Initializing Default Publisher. #{params}" }
      params[:file_path_field_name] = DEFAULT_FILE_PATH_FIELD_NAME
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
        process_document_files
      else
        doc_type = document_type
      end

      #{ :files => files, :sequences => sequences }

      @results
    end # process

    def process_document_files(params = {})
      _files = @files.dup

      run_mig = params.fetch(:run_mig, true)

      _files.map do |file|
        full_file_path = file[DEFAULT_FILE_PATH_FIELD_NAME]

        if run_mig
          _mig = run_mig_on_file(full_file_path)
          file[:metadata_sources] = _mig ? _mig.metadata_sources : { }
        else
          logger.debug { 'Media Information Gathering SKIPPED. run_mig set to false.' }
        end
        file
      end

      publisher_results = @publisher.publisher.process_objects(_files)
      _results = [ ]
      _files.each do |file|
        _results << { file_path: file, results: publisher_results.shift }
      end
      @results[:files] = _results
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