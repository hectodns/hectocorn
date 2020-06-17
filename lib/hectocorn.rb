require 'json'


module Hectocorn
  require 'hectocorn/action'
  require 'hectocorn/logger'

  HECTODNS_ENVIRON_VAR= "hectodns.options"

  @@opts = nil
  @@logger = nil

  def self.options
    @@opts = @@opts || self.parse_options
    return @@opts
  end

  def self.infinite_loop(&block)
    action = Hectocorn::Action.new
    action.mount(&block)

    # Infinitely process requests one by one.
    while true
      action.run
    end
  end

  def self.logger
    @@logger = @@logger || Hectocorn::Logger.new
    return @@logger
  end

private

  def self.parse_options
    opts = ENV[HECTODNS_ENVIRON_VAR]
    return opts ? JSON.parse(opts) : {}
  end
end
