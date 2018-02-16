# frozen_string_literal: true

module ECS
  # Logger class
  class ECSLog
    include Singleton
    attr_accessor :log
    def initialize
      @log = Logger.new(STDOUT)
      @log.level = Logger::DEBUG
    end
  end
end
