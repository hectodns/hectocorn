module Hectocorn
  require 'hectocorn/action'

  def self.infinite_loop(&block)
    action = Hectocorn::Action.new
    action.mount(&block)

    # Infinitely process requests one by one.
    while true
      action.run
    end
  end
end
