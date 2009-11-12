require 'socket'

# example:
# ruby -Ilib -rir -rir/socket_readline -e "Ir::SocketReadline.new"
# telnet localhost 7829

class Ir
  class SocketReadline
    DEFAULTS = {
      :tty_exit_on_eof => false,
      :term => "\r\0"
    }
    def initialize(host = '127.0.0.1', port = 7829, options = {})
      @options = DEFAULTS.merge(options)
      @server = TCPServer.new(host, port)
      @running = true
      while @running
        s = @server.accept
        Thread.new { 
          options = @options.merge(:tty_exit_callback => lambda { s.close })
          Readline.new(s, s, options)
        }.abort_on_exception = true
      end
    end
    
    def stop
      @running = false
    end
  end
end