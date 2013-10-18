require 'sinatra'

class MediaInformationGatherer

  class HTTP < Sinatra::Base
    enable :logging
    disable :protection

    post '/' do
      logger.level = Logger::DEBUG
      logger.debug { "Params: #{params}" }
      #return params

      response = { }
      file_paths = params[:file_paths]
      [*file_paths].each { |file_path|
        begin
          response[file_path] = settings.mig.run(file_path)
        rescue => e
          response[file_path] = { :exception => { :message => e.message, :backtrace => e.backtrace } }
        end
      }
      JSON.generate(response)
    end # post '/'

  end # HTTP

end # MediaInformationGatherer
