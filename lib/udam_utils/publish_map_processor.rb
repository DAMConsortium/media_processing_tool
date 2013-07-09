$:.unshift(File.expand_path('../'))
require 'logger'
require 'open3'
require 'pp'
require 'shellwords'
#require 'udam_utils'


module UDAMUtils

  class BasePublishMapProcessor

    class << self
      def publish_map=(value); @publish_map = value end # publish_map=
      def publish_map; @publish_map end # publish_map

      def process(params = { })
        #new(params).process
      end # self.process

      # @param [Hash] hash
      # @param [Symbol|String|Array<Symbol, String>] keys
      # @param [Hash] options
      # @option options [Any] :default The default value to return if none of the keys are found
      # @option options [Boolean] :search_keys_as_string
      def search_hash(hash, keys, options = { })
        value = options[:default]
        search_keys_as_string = options[:search_keys_as_string]
        [*keys].each do |key|
          value = hash[key] and break if hash.has_key?(key)
          if search_keys_as_string
            key = key.to_s
            value = hash[key] and break if hash.has_key?(key)
          end
        end
        value
      end # search_keys

    end # self

    attr_accessor :logger

    def initialize(params = {})
      @logger = params[:logger] || Logger.new(params[:log_to] || STDOUT)
      load_configuration_from_file(params)

      @publish_maps ||= @publish_map || params[:publish_maps] || params[:publish_map]
      raise RuntimeError, "Missing or Empty @publish_maps.\n Check your configuration in #{options[:config_file_path]}" unless (@publish_maps.is_a?(Array) and !@publish_maps.empty?)
    end # initialize

    # @param [Hash] params
    # @option params [String] :config_file_path
    def load_configuration_from_file(params = { })
      params = params.dup

      case params
        when String
          config_file_path = params
          params = { }
        when Hash
          config_file_path = params[:config_file_path] || params[:configuration_file_path]
        when Array
          case params.first
            when String
              config_file_path = params.shift
              params = params.first.is_a?(Hash) ? params.first : { }
            when Hash; params = params.shift
            else params = { }
          end
      end # case params
      return false unless config_file_path
          #raise ArgumentError, 'config_file_path is a required argument.' unless config_file_path

      raise "Configuration File Not Found. '#{config_file_path}'" unless File.exists?(config_file_path)
      logger.debug { "Loading Configuration From File. #{config_file_path}"}

      #require config_file_path
      eval(File.open(config_file_path, 'r').read)
    end # load_configuration_from_file

    # @param [Hash] hash
    # @param [Symbol|String|Array<Symbol, String>] keys
    # @param [Hash] options
    # @option options [Any] :default The default value to return if none of the keys are found
    # @option options [Boolean] :search_keys_as_string
    def search_hash(hash, keys, options = { })
      value = options[:default]
      search_keys_as_string = options[:search_keys_as_string]
      [*keys].each do |key|
        value = hash[key] and break if hash.has_key?(key)
        if search_keys_as_string
          key = key.to_s
          value = hash[key] and break if hash.has_key?(key)
        end
      end
      value
    end # search_keys

  end # BasePublishMapProcessor


  class WorkflowPublishMapProcessor < BasePublishMapProcessor

    attr_accessor :event

    # @param [Hash] params
    # @option params [Object] :logger
    # @option params [String] :uu_executable ([UDAMUtils.bin_dir]/uu)
    # @option params [Boolean] :confirm_filtered_vents NOT CURRENTLY USED
    # @option params [Hash] :publish_map
    # @option params [Symbol, String] :event_id_field_name (:id)
    # @option params [Symbol, String] :event_type_field_name (:type)
    # @option params [Symbol, String] :entity_path_field_name (:path)
    def initialize(params = { })
      super(params)

      logger.debug { "Initializing Workflow Publish Map Processor. #{params}" }

      options = params
      @uu_bin_dir = '/usr/bin' #|| UDAMUtils.get_bin_dir

      @udam_utils_exec = options[:uu_executable] ||= File.join(@uu_bin_dir, 'uu')
      raise "UDAM Utils Executable Not Found. File Not Found: '#{@udam_utils_exec}'" unless File.exist?(@udam_utils_exec)
      logger.debug { "UDAM Utils Executable: #{@udam_utils_exec}" }

      #@get_events_exec = options[:get_events_exec] ||= File.join(mre_bin_dir, 'get_events_with_metadata.rb')
      #raise "Get Events Executable Not Found. File Not Found: '#{@get_events_exec}'" unless File.exist?(@get_events_exec)
      #@logger.debug { "Get Events Exec: #{@get_events_exec}" }

      #@confirm_event_exec = options[:confirm_event_exec] ||= File.join(mre_bin_dir, 'confirm_event.rb')
      #raise "Confirm Events Executable Not Found. File Not Found: '#{@confirm_event_exec}'" unless File.exist?(@confirm_event_exec)
      #@logger.debug { "Confirm Event Exec: #{@confirm_event_exec}" }

      # Determines if events that are set to not be published still get confirmed by default
      @confirm_filtered_events ||= params[:confirm_filtered_events] ||= false
      logger.debug { "Confirm Filtered Events: #{@confirm_filtered_events}" }

      @event_id_field_name ||= params[:event_id_field_name] || :id
      @event_id_field_name = @event_id_field_name.to_sym if @event_id_field_name.is_a?(String)

      @event_type_field_name ||= params[:event_type_field_name] || :type
      @event_type_field_name = @event_type_field_name.to_sym if @event_type_field_name.is_a?(String)

      @entity_field_name ||= params[:entity_field_name] || :entity
      @entity_field_name = @entity_field_name.to_sym if @entity_field_name.is_a?(String)

      @entity_path_field_name ||= params[:entity_path_field_name] || :path
      @entity_path_field_name = @entity_path_field_name.to_sym if @entity_path_field_name.is_a?(String)
    end # initialize

    # @param [Hash] parameters
    # @param [Hash] event
    # @return [Hash]
    def eval_workflow_parameters(parameters, event = @event)
      workflow_parameter_values = { }
      parameters.each { |pname, param|
        logger.debug { "Processing Workflow Parameter: #{pname} -> #{param}" }
        case param
          when String
            pv = param
            eval_pv = true
          when Hash
            pv = param.fetch(:value, nil)
            eval_pv = param.fetch(:eval, false)
          else
            pv = nil
            eval_pv = false
        end
        begin
          pv = eval(pv) if eval_pv && pv.is_a?(String)
          logger.debug { "Processed Workflow Parameter: #{pname} -> #{pv}" }
          workflow_parameter_values[pname] = pv
        rescue => e
          logger.error { "Failed to evaluate parameter. #{e.message}\nName: #{pname}\nValue: #{param}" }
        end
      }
      workflow_parameter_values
    end # eval_workflow_parameters

    # @param [Hash] params
    # @option params [Hash] :event
    # @option params [Hash] :workflow A hash containing the :name and optionally the :parameters key for the workflow to execute
    # @option params [String] :mq_connection_uri The connection URI to use when publishing the workflow.
    # @return [Boolean]
    def publish_to_workflow(params = { })
      event = params.fetch(:event, @event)
      workflow = params.fetch(:workflow, @publish_params.fetch(:workflow, nil))
      mq_connection_uri = params.fetch(:mq_connection_uri, nil)

      logger.debug { "Publishing To Workflow. Workflow: #{workflow}" }
      unless (workflow_name = workflow.fetch(:name, false))
        logger.error "No Workflow Name Specified. Event: #{event} Workflow: #{workflow}"
        return false
      end

      workflow_parameters = workflow.fetch(:parameters, false)
      workflow_parameter_values = eval_workflow_parameters(workflow_parameters, event) if workflow_parameters
      workflow_parameter_values ||= { }

      cmd_line = [ @udam_utils_exec, 'job', '--workflow', workflow_name, '--workflow-parameters', workflow_parameter_values.to_json]
      cmd_line << '--mq-connection-uri' << mq_connection_uri if mq_connection_uri
      cmd_line = cmd_line.shelljoin

      logger.debug { "Publishing event using command line. #{cmd_line}" }
      response = execute(cmd_line)
      logger.debug { "Publish event command response: #{response}" }
      response[:success]
    end # publish_event_to_workflow

    # @param [String] cmd_line The command line to execute
    # @return [Hash] { "STDOUT" => [String], "STDERR" => [String], "STATUS" => [Object] }
    def execute(cmd_line)
      begin
        stdout_str, stderr_str, status = Open3.capture3(cmd_line)
        logger.error { "Error Executing #{cmd_line}. Stdout: #{stdout_str} Stderr: #{stderr_str}" } unless status.success?
        return { :stdout => stdout_str, :stderr => stderr_str, :status => status, :success => status.success? }
      rescue
        logger.error { "Error Executing '#{cmd_line}'. Exception: #{$!} @ #{$@} STDOUT: '#{stdout_str}' STDERR: '#{stderr_str}' Status: #{status.inspect} " }
        return { :stdout => stdout_str, :stderr => stderr_str, :status => status, :success => false }
      end
    end # execute

    # @param [Hash] event
    def parse_event(event = @event)
      # Since the event came in and was converted from JSON all of the keys are strings instead of symbols

      begin
        @object = @event
        @event_id = event[@event_id_field_name] || event[@event_id_field_name.to_s]
        @event_type = event[@event_type_field_name] || event[@event_type_field_name.to_s]

        entity = event.fetch(@entity_field_name, event)
        @full_file_path = entity.fetch(@entity_path_field_name)

        @metadata_sources = entity.fetch(:metadata_sources, { })
        @exiftool = @metadata_sources[:exiftool] ||= { }
        @mediainfo = @metadata_sources[:mediainfo] ||= { }
        @ffmpeg = @metadata_sources[:ffmpeg] ||= { }
        @filemagic = @metadata_sources[:filemagic] ||= { }
        @media = @metadata_sources[:filemagic] ||= { }
        @common_media_info = @metadata_sources[:common] ||= { }

        #media = entity.fetch('media', { })
        @media_type = @media[:type] || @media['type']
        @media_subtype = @media[:subtype] || @media['subtype']
      rescue => e
        logger.error "Error parsing event.\n\tEvent: #{event.inspect}\n\n\tException #{e.message}\n\tBacktrace #{e.backtrace}"
        raise
      end
    end # parse_event

    # @param [Hash] event
    def process_event(event = @event)
      @event = event
      logger.debug { "Processing Event: \n\n #{PP.pp(event, '')}" }
      ignore_publish_error = false

      parse_event(event) #rescue return

      if match_found_in_publish_maps?

        # Determines if the event is to be published
        # Defaults to true so that that it doesn't have to be defined for every workflow map
        map_publish_event = @publish_params.fetch(:publish_event, true)

        # Determines if the event is to be confirmed
        # Defaults to true so that that it doesn't have to be defined for every workflow map
        map_confirm_event = @publish_params.fetch(:confirm_event, true)

        # Determines if the event will still get confirmed if there is an error during publishing
        ignore_publish_error = @publish_params.fetch(:ignore_publish_error, false)
      else
        map_publish_event = nil
        map_confirm_event = nil
      end

      to_publish = map_publish_event
      to_confirm = (map_confirm_event or @confirm_filtered_events)

      if to_publish
        publish_response = publish_event
        publish_successful = publish_response[:success]
        confirm_response = confirm_event(@event_id) if (publish_successful or ignore_publish_error) and map_confirm_event
      elsif to_confirm
        logger.debug { "Event is being confirmed but not published. Included Event: #{!map_publish_event.nil?} Map Publish Content: #{map_publish_event} Confirm Filtered Events: #{@confirm_filtered_events} Map Confirm Event: #{map_confirm_event} Event: #{event.inspect}"}
        confirm_response = confirm_event(@event_id)
      else
        publish_successful = publish_response = confirm_successful = confirm_response = nil
      end
      confirm_successful = confirm_response[:success] if confirm_response

      {
        to_publish: map_publish_event,
        to_confirm: to_confirm,
        published: (publish_successful or ignore_publish_error),
        confirmed: confirm_successful,
        publish_response: publish_response,
        confirm_response: confirm_response,
        success:  (
        (!to_publish or (to_publish and publish_successful)) and
            (!to_confirm or (to_confirm and confirm_successful))
        )
      }
    end # process_event

    # # @param [Array(Hash)] events
    # @param [Array(Hash)] events
    def process_events(events)
      @event = nil
      events.each do |event|
        @event = event
        begin
          process_event
        rescue StandardError, ScriptError => e
          logger.error "Error processing event.\n\tEvent: #{event.inspect}\n\n\tException #{e.inspect}"
        end
      end
    end # process_events

    # @param [String|Integer] event_id
    # @param [Hash] event
    # @param [Hash] params
    # @option params [String|nil] :publish_event_exec
    # @option params [Boolean|nil] (false) :eval_publish_event_exec
    # @option params [String|nil] :publish_event_arguments
    # @option params [Boolean|nil] (true) :eval_publish_event_exec
    # @return [Boolean]
    def publish_event(event = @event, params = @publish_params)

      workflow = params.fetch(:workflow, false)
      return publish_event_to_workflow(workflow: workflow) if workflow

      exec = params.fetch(:publish_event_exec, nil)
      eval_publish_event_exec = params.fetch(:eval_publish_event_exec, false)

      arguments = params.fetch(:publish_event_arguments, nil)
      eval_publish_event_arguments = params.fetch(:eval_publish_event_arguments, true)

      logger.debug { "Evaluating exec: #{exec}" } and exec = eval(exec) if eval_publish_event_exec and exec
      logger.debug { "Evaluating arguments: #{arguments}" } and arguments = eval(arguments) if eval_publish_event_arguments and arguments
      cmd_line = "#{exec} #{arguments}" if arguments
      logger.debug { "Publishing event using command line. #{cmd_line}" }
      response = execute(cmd_line)
      logger.debug { "Publish event command response: #{response}" }
      response
    end # publish_event

    # @param [Hash] event
    # @param [Hash] workflow
    # @return [Boolean]
    def publish_event_to_workflow(params = { })
      event = params.fetch(:event, @event)
      workflow = params.fetch(:workflow, @publish_params.fetch(:workflow, nil))


      logger.debug { "Publishing Event To Workflow. Workflow: #{workflow}" }
      unless (workflow_name = workflow.fetch(:name, false))
        logger.error "No Workflow Name Specified. Event: #{event} Workflow: #{workflow}"
        return false
      end

      workflow_parameters = workflow.fetch(:parameters, false)
      workflow_parameter_values = eval_workflow_parameters(workflow_parameters, event) if workflow_parameters
      workflow_parameter_values ||= { }

      cmd_line = [ @udam_utils_exec, 'job', '--workflow', workflow_name, '--workflow-parameters', workflow_parameter_values.to_json].shelljoin
      logger.debug { "Publishing event using command line. #{cmd_line}" }
      response = execute(cmd_line)
      logger.debug { "Publish event command response: #{response}" }
      response
    end # publish_event_to_workflow


    # @params [Hash] publish_maps
    def match_found_in_publish_maps?(publish_maps = @publish_maps)
      matched = false
      publish_maps.each { |current_publish_map|
        current_publish_map = { type: :glob, map: current_publish_map } if current_publish_map.is_a?(Array)

        map_type = current_publish_map.fetch(:type, :unknown)
        map = current_publish_map.fetch(:map, false)
        logger.warn { "Mapping with no map detected. #{current_publish_map}"} and next unless map

        case map_type
          when :eval
            matched = search_eval_publish_map(current_publish_map)
          when :media_type
            matched = search_media_type_publish_map(current_publish_map)
          when :glob
            matched = search_glob_publish_map(current_publish_map)
          when :global
            matched = search_global_publish_map(current_publish_map)
          else
            logger.warn { "Unknown map type '#{map_type}'."}
        end
        break if matched
      }
      matched
    end # process_publish_maps

    def init_publish_params(params_by_event_type)
      return false unless params_by_event_type

      @publish_params = params_by_event_type[@event_type.to_sym] || params_by_event_type[@event_type.to_s]
      @publish_params ||= params_by_event_type[:any] || params_by_event_type['any']
      @publish_params ||= params_by_event_type[:all] || params_by_event_type['all']
      @publish_params
    end

    # @params [Hash] params
    # @option params [Hash] :map
    def search_eval_publish_map(params = { })
      logger.debug { 'Starting Eval Search.' }
      map = params.fetch(:map, false)
      return false unless map

      match_found = false
      map.each { |expressions, map_params|
        @logger.debug { "Testing expressions. #{expressions} #{map_params}" }
        next unless init_publish_params(map_params)
        [*expressions].each { |expression| logger.debug { "Matched expression: #{expression}" } and match_found = true and break if eval(expression) }
        break if match_found
      }
      match_found
    end # search_eval_publish_map

    # @params [Hash] params
    # @option params [Hash] :map
    def search_media_type_publish_map(params = { })
      logger.debug { 'Starting Media Type Search.' }
      map = params.fetch(:map, false)
      return false unless map

      logger.warn("Asset media type is empty. #{@object}") and return false unless @media_type
      logger.warn("Asset media subtype is empty. #{@object}") and return false unless @media_subtype

      match_found = false
      map.each { |media_types, media_subtypes_with_params|
        [*media_types].each { |media_type|
          next unless media_type.match(@media_type)
          media_subtypes_with_params.each { |media_subtypes, map_params|
            next unless init_publish_params(map_params)
            [*media_subtypes].each { |media_subtype|
              logger.debug { "Matched media type: #{media_type.to_s}/#{media_subtype.to_s} -> #{@media_type}/#{@media_subtype}" } and match_found = true and break if media_subtype.match(@media_subtype)
            }
          }
          break if match_found
        }
        break if match_found
      }
      logger.debug { "Media Type Search Completed. Match Found: #{match_found}" }
      match_found
    end # search_media_type_publish_map

    # @params [Hash] params
    # @option params [Hash] :map
    # @option params [Integer] :options
    def search_glob_publish_map(params = { })
      logger.debug { 'Starting Glob Search.' }
      map = params.fetch(:map, false)
      return false unless map

      logger.debug { "MAP: #{map}" }

      full_file_path = @full_file_path
      logger.warn("Full file path is empty. #{@object}") and return false unless full_file_path

      event_type = @event_type

      match_found = false

      default_glob_options = params.fetch(:options, 0)
      default_glob_options = 0 unless default_glob_options.is_a? Integer

      map.each { |patterns, map_params|
        next unless init_publish_params(map_params)

        if patterns.is_a?(Hash)
          globs = patterns[:globs] || patterns[:glob] || { }
          glob_options = patterns.fetch(:options, default_glob_options)
          glob_options = 0 unless glob_options.is_a? Integer
        else
          globs = patterns
          glob_options = default_glob_options
        end

        [*globs].each do |pattern|
          logger.debug { "Testing #{full_file_path} against #{pattern} with options #{glob_options}" }
          if File.fnmatch(pattern, full_file_path, glob_options)
            logger.debug { "Matched pattern: #{full_file_path} -> #{pattern}" }
            match_found = true
            break
          end
        end
        break if match_found
      }
      match_found
    end # search_glob_publish_map

    # Processes a catch all publish map
    #
    # { type: :global, map: { anything: all: { publish_event: false, confirm_event: false } } }
    # Where :anything is ignored and :all can be anyone of :all, :created, :modified, :deleted
    #
    # @params [Hash] params
    # @option params [Hash] :map
    def search_global_publish_map(params = { })
      logger.debug { 'Starting Global Search.' }
      return false unless (map = params[:map])

      match_found = false
      map.each { |ignored, params_by_event_type|
        next unless init_publish_params(params_by_event_type)
        match_found = true
        break
      }
      match_found
    end # search_global_publish_map

    def confirm_event(*args)
      { :stdout => '', :stderr => '', :status => '', :success => true }
    end # confirm_event

  end # WorkflowPublishMapProcessor

  class EventBasedPublishMapProcessor < WorkflowPublishMapProcessor

  end # EventBasedPublishMapProcessor

  class GenericPublishMapProcessor < WorkflowPublishMapProcessor

    attr_accessor :object

    def initialize(params = {})
      super(params)
      @full_file_path_field_name = params[:file_path_field_name]
    end # initialize


    def init_publish_params(params)
      # We don't have events so the params are the params, there is not an 'event type' as a key in between
      @publish_params = params
      @publish_params
    end # init_publish_params

    def parse_object(object = @object, params = { })
      logger.debug { "Parsing Object: #{PP.pp(object, '')}" }
      begin
        @full_file_path = object[@full_file_path_field_name]

        @metadata_sources = object.fetch(:metadata_sources, { })
        @exiftool = @metadata_sources[:exiftool] ||= { }
        @mediainfo = @metadata_sources[:mediainfo] ||= { }
        @ffmpeg = @metadata_sources[:ffmpeg] ||= { }
        @filemagic = @metadata_sources[:filemagic] ||= { }
        @media = @metadata_sources[:filemagic] ||= { }
        @common_media_info = @metadata_sources[:common] ||= { }

        #media = entity.fetch('media', { })
        @media_type = @media[:type] || @media['type']
        @media_subtype = @media[:subtype] || @media['subtype']
      rescue => e
        logger.error "Error parsing object.\n\tObject: #{object.inspect}\n\n\tException #{e.message}\n\tBacktrace #{e.backtrace}"
        raise
      end
    end # parse_event


    # @param [Array<Hash>] objects
    def process_objects(objects, params = {})
      results = [ ]
      @object = nil
      [*objects].each do |object|
        @object = object
        begin
          results << process_object
        rescue StandardError, ScriptError => e
          logger.error "Error processing event.\n\tObject: #{object.inspect}\n\n\tException #{e.inspect}"
          results << { success: false, error: { message: e.message }, exception: { message: e.message, backtrace: e.backtrace }, object: object }
        end
      end
      results
    end # process_events

    def process_object(params = { })
      @object = params[:object] if params.has_key?(:object)
      logger.debug { "Processing Object: \n\n #{PP.pp(object, '')}" }
      parse_object
      ignore_publish_error = false

      #parse_event(event) #rescue return

      if match_found_in_publish_maps?

        # Determines if the event is to be published
        # Defaults to true so that that it doesn't have to be defined for every workflow map
        map_publish = @publish_params.fetch(:publish, true)

        # Determines if the event is to be confirmed
        # Defaults to true so that that it doesn't have to be defined for every workflow map
        map_confirm = @publish_params.fetch(:confirm, true)

        # Determines if the event will still get confirmed if there is an error during publishing
        ignore_publish_error = @publish_params.fetch(:ignore_publish_error, false)
      else
        map_publish = nil
        map_confirm = nil
      end

      to_publish = map_publish
      to_confirm = (map_confirm or @confirm_filtered_objects)

      if to_publish
        publish_response = publish
        publish_successful = publish_response[:success]
        confirm_response = confirm(@object_id) if (publish_successful or ignore_publish_error) and map_confirm
      elsif to_confirm
        logger.debug { "Confirming but not published. Map Publish Content: #{map_publish} Confirm Filtered: #{@confirm_filtered_events} Map Confirm Event: #{map_confirm} Object: #{object.inspect}"}
        confirm_response = confirm(@object_id)
      else
        publish_successful = publish_response = confirm_successful = confirm_response = nil
      end
      confirm_successful = confirm_response[:success] if confirm_response

      {
        to_publish: to_publish,
        to_confirm: to_confirm,
        published: (publish_successful or ignore_publish_error),
        confirmed: confirm_successful,
        publish_response: publish_response,
        confirm_response: confirm_response,
        success: (
        (!to_publish or (to_publish and publish_successful)) and
            (!to_confirm or (to_confirm and confirm_successful))
        )
      }
    end # process_object

    # @param [Hash] params
    # @option params [Hash] :object
    # @option params [Hash] :workflow
    # @return [Boolean]
    def publish_to_workflow(params = { })
      object = params.fetch(:object, @object)
      workflow = params[:workflow]
      workflow ||= @publish_params[:workflow] if @publish_params.is_a?(Hash)

      logger.debug { "Publishing To Workflow. Workflow: #{workflow}" }
      unless (workflow_name = workflow.fetch(:name, false))
        logger.error "No Workflow Name Specified. Object: #{object} Workflow: #{workflow}"
        return false
      end

      workflow_parameters = workflow.fetch(:parameters, false)
      workflow_parameter_values = eval_workflow_parameters(workflow_parameters, object) if workflow_parameters
      workflow_parameter_values ||= { }

      cmd_line = [ @udam_utils_exec, 'job', '--workflow', workflow_name, '--workflow-parameters', workflow_parameter_values.to_json].shelljoin
      logger.debug { "Publishing event using command line. #{cmd_line}" }
      response = execute(cmd_line)
      logger.debug { "Publish event command response: #{response}" }
      response
    end # publish_to_workflow

    # @param [String|Integer] event_id
    # @param [Hash] object
    # @param [Hash] params
    # @option params [String|nil] :publish_event_exec
    # @option params [Boolean|nil] (false) :eval_publish_event_exec
    # @option params [String|nil] :publish_event_arguments
    # @option params [Boolean|nil] (true) :eval_publish_event_exec
    # @return [Boolean]
    def publish(object = @object, params = @publish_params)

      workflow = params.fetch(:workflow, false)
      return publish_to_workflow(workflow: workflow) if workflow

      exec = search_hash(params, [:publish_executable, :publish_exec, :publish_event_exec])
      eval_publish_exec = search_hash(params, [:eval_publish_executable, :eval_publish_exec, :eval_publish_event_exec])

      arguments = search_hash(params, [:publish_arguments, :publish_event_arguments])
      eval_publish_arguments = search_hash(params, [:eval_publish_arguments, :eval_publish_event_arguments], default: true)

      logger.debug { "Evaluating exec: #{exec}" } and (exec = eval(exec)) if eval_publish_exec and exec
      logger.debug { "Evaluating arguments: #{arguments}" } and (arguments = eval(arguments)) if eval_publish_arguments and arguments

      if exec
        cmd_line = arguments ? "#{exec} #{arguments}" : exec
      else
        cmd_line = arguments
      end

      logger.debug { "Publishing using command line. #{cmd_line}" }
      response = execute(cmd_line)
      logger.debug { "Publish command response: #{response}" }
      response
    end # publish

    def confirm(params = {})

    end # confirm

  end # GenericPublishMapProcessor

end # UDAMUtils

