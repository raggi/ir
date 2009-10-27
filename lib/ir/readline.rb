require 'readline'

class Ir
  class Readline < Tty
    TERM = "\n"
    DEFAULTS = {
      :term => TERM,
      # Darwin readline bug!
      # TODO - support native readline build here, more cleanly
      :puts_on_interrupt => RUBY_PLATFORM !~ /darwin/
    }

    def initialize(output = $stdout, options = {})
      super($stdin, $stdout, DEFAULTS.merge(options))
    end

    def consume
      exit_on_eof do
        interruptable do
          if line = ::Readline.readline(@ir.prompt)
            @ir << line + TERM
          else
            raise EOFError
          end
        end while true
      end
    end
  end
end