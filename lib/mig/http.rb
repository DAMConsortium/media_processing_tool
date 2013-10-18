require 'json'
require 'sinatra/base'

class MediaInformationGatherer

  class HTTP < Sinatra::Base
    enable :logging
    disable :protection

    # Will try to convert a body to parameters and merge them into the params hash
    # Params will override the body parameters
    #
    # @params [Hash] _params (params) The parameters parsed from the query and form fields
    def merge_params_from_body(_params = params)
      _params = _params.dup
      if request.media_type == 'application/json'
        request.body.rewind
        body_contents = request.body.read
        logger.debug { "Parsing: '#{body_contents}'" }
        if body_contents
          json_params = JSON.parse(body_contents)
          if json_params.is_a?(Hash)
            _params = json_params.merge(_params)
          else
            _params['body'] = json_params
          end
        end
      end
      _params
    end # merge_params_from_body


    post '/' do
      logger.level = Logger::DEBUG
      _params = merge_params_from_body
      logger.debug { "Params: #{_params}" }
      #return params

      response = { }
      file_paths = _params['file_paths']
      [*file_paths].each do |file_path|
        begin
          response[file_path] = settings.mig.run(file_path)
        rescue => e
          response[file_path] = {:exception => {:message => e.message, :backtrace => e.backtrace}}
        end
      end
      JSON.generate(response)
    end # post '/'

  end # HTTP

end # MediaInformationGatherer
