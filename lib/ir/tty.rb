class Ir
  class Tty
    DEFAULTS = {
      :tty_exit_on_eof => true
    }
    def initialize(input = $stdin, output = $stdout, options = {})
      options = DEFAULTS.merge(options)
      @exit_callback = options[:tty_exit_callback]
      @exit_on_eof = options[:tty_exit_on_eof]
      @input = input
      @output = output
      @ir = Ir.new(options.merge(:output => self))
      consume
    end

    def consume
      exit_on_eof do
        interruptable do
          print @ir.prompt
          @ir << @input.readline
        end while true
      end
    end

    def print(*args)
      exit_on_eof do
        @output.print(*args)
        @output.flush
      end
    end

    def puts(*args)
      exit_on_eof { @output.puts(*args) }
    end

    private
    def interruptable
      yield
    rescue Interrupt
      @ir.interrupt
    end

    def exit_on_eof
      yield
    rescue EOFError
      puts # TODO optionme?
      @exit_callback.call if @exit_callback
      exit if @exit_on_eof
    end
  end
end