require 'hectocorn'

# External dependencies.
require 'dnsruby'

# Stdlib dependencies.
require 'stringio'
require 'webrick'


DNS = Dnsruby


class Hectocorn::Request
  attr_accessor :header, :msg

  def initialize(header, msg)
    @header = header
    @msg = msg
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
    httpreq = WEBrick::HTTPRequest.new(WEBrick::Config::HTTP)
    httpreq.parse(@input)

    # Decode DNS request from the body of the HTTP request.
    msg = DNS::Message::decode(httpreq.body)
    return Hectocorn::Request.new(httpreq.header, msg)
  end
end
