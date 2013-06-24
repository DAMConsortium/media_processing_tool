require 'logger'
module FinalCutPro

  attr_writer :logger

  # @param [Hash] options
  # @option options [Object|nil] :logger (Logger)
  # @option options [String|Object] :log_to (STDERR)
  # @option options [Fixnum] :log_level (3)
  def self.process_options_for_logger(options = { })
    _logger = options[:logger]
    unless _logger
      if options[:log_to] or options[:log_level]
        _logger = Logger.new(options[:log_to] || STDERR)
        _logger.level = options[:log_level] if options[:log_level]
      else
        _logger = logger
      end
    end
    @logger ||= _logger
    _logger
  end # process_options_for_logger

  def self.logger
    return @logger if @logger
    @logger = Logger.new(STDERR)
    @logger.level = Logger::ERROR
    @logger
  end # self.logger

end # FinalCutPro