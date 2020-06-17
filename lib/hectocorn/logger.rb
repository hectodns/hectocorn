require 'hectocorn'


class Hectocorn::Logger
  def initialize(logdev = $stderr)
    @logdev = logdev
  end

  %w(debug info warn error).each do |level|
    define_method(level) do |msg|
      log(level, msg)
    end
  end

private
  def log(level, msg)
    @logdev.puts "#{level[0]}:#{msg}"
  end
end
