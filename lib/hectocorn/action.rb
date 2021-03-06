require 'hectocorn'

# External dependencies.
require 'dnsruby'

# Stdlib dependencies.
require 'stringio'
require 'webrick'


DNS = Dnsruby


class Hectocorn::Request
  attr_accessor :header, :msg

  attr_reader :remote_addr, :local_addr

  def initialize(header, msg)
    @header = header || {}
    @msg = msg

    parse_header!
  end

private
  def parse_header!
    @remote_addr, @local_addr = parse_forwarded(@header)
  end

  def parse_forwarded(header)
    raw_header = header.fetch("forwarded", [""]).first
    raw_directives = raw_header.split(";")

    # Each directive in the "Forwarded" header, is represented
    # by a key followed by equal sign and quotted value.
    directives = raw_directives.to_h do |dir|
      dir.split("=").map { |s| unquote(s) }
    end

    # Remote and loca addresses represnted by "for" and "by"
    # directive respectively.
    return directives["for"], directives["by"]
  end

  def unquote(str)
    return str.delete_prefix('"').delete_suffix('"') if str
  end
end


class Hectocorn::Response
  attr_accessor :msg

  def initialize
    @resp = WEBrick::HTTPResponse.new(WEBrick::Config::HTTP)
    @msg = DNS::Message.new
  end

  def redirect!
    @resp.status = WEBrick::HTTPStatus::RC_TEMPORARY_REDIRECT
  end

  def serialize
    body = @msg.encode()

    resp = @resp.dup
    resp.status = 200
    resp.content_length = body.size
    resp.body = body

    io = StringIO.new
    resp.send_response(io)

    return io.string
  end
end


class Hectocorn::Action
  def initialize(input = $stdin, output = $stdout)
    @input = input
    @output = output
    @proc = nil
  end

  def mount(&block)
    @proc = block
    self
  end

  def run
    req = parse_request
    req_id = req.msg.header.id

    resp = Hectocorn::Response.new
    @proc.call(req, resp)

    resp.msg.header.id = req_id

    # Write response back to the caller.
    @output.write(resp.serialize)
    @output.flush
  end

protected

  def parse_request
    begin
      httpreq = WEBrick::HTTPRequest.new(WEBrick::Config::HTTP)
      httpreq.parse(@input)
    rescue WEBrick::HTTPStatus::RequestTimeout
      retry
    end

    # Decode DNS request from the body of the HTTP request.
    msg = DNS::Message::decode(httpreq.body)
    return Hectocorn::Request.new(httpreq.header, msg)
  end
end
