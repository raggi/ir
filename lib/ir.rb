class Ir
  class Tty
    DEFAULTS = {
      :tty_exit_on_eof => true
    }
    def initialize(input = $stdin, output = $stdout, options = {})
      options = DEFAULTS.merge(options)
      @exit_on_eof = options[:tty_exit_on_eof]
      @input = input
      @output = output
      @ir = Ir.new(options.merge(:output => self))
      consume
    end

    def consume
      exit_on_eof { interruptable { @ir << @input.readline } while true }
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
      exit if @exit_on_eof
    end
  end

  class Readline < Tty
    TERM = "\n"
    DEFAULTS = {
      :term => TERM,
      # Darwin readline bug!
      # TODO - support native readline build here, more cleanly
      :puts_on_interrupt => RUBY_PLATFORM !~ /darwin/
    }

    def initialize(output = $stdout, options = {})
      require 'readline'
      super($stdin, $stdout, DEFAULTS.merge(options))
    end

    def consume
      exit_on_eof do
        interruptable do
          if line = ::Readline.readline
            @ir << line + TERM
          else
            raise EOFError
          end
        end while true
      end
    end
  end

  FROM = "\tfrom "

  PROMPTS = {}
  PROMPTS[:simple] = {
    :normal => '>> ',
    :syntax => ' > ',
    :notify => '#> ',
    :result => '=> '
  }

  COMPLEX_PROMPT = lambda do |name, lineno, prompt|
    name + (":%-3d" % lineno) + PROMPTS[:simple][prompt]
  end
  PROMPTS[:complex] = {
    :normal => COMPLEX_PROMPT,
    :syntax => COMPLEX_PROMPT,
    :notify => COMPLEX_PROMPT,
    :result => COMPLEX_PROMPT
  }

  DEFAULTS = {
    :name => '(ir)',
    :binding => TOPLEVEL_BINDING,
    :output => $stdout,
    :term => "\n",
    :thread_local_var => :ir,
    :clear_on_interrupt => false,
    :puts_on_interrupt => true,
    :prompts => PROMPTS[:complex],
    :inspector => lambda { |ir, o| ir.results o.inspect }
  }

  def initialize(options = {})
    @options = DEFAULTS.merge(options)
    @prompts, @output, @name = *@options.values_at(:prompts, :output, :name)
    @inspector, @binding = @options.values_at(:inspector, :binding)
    @term = @options[:term]
    @buffer, @bufferline, @inputline, @prompt = '', 1, 1, :normal
    # So runtimes can do: Thread.current[:ir].notify "OHAI"
    Thread.current[@options[:thread_local_var]] = self
    prompt
  end

  def prompt(name = nil, lineno = nil)
    lineno ||= @inputline
    name ||= @prompt
    prompt = @prompts[name]
    case prompt
    when String
      print prompt
    when Proc
      print prompt.call(@name, lineno, name)
    else
      print prompt.to_s
    end
  end

  # Lines are expected to include the \n
  def <<(data)
    @buffer << data
    @inputline += data.count(@term)
    syntax? ? consume : @prompt = :syntax
    prompt
  end

  def syntax?
    catch(:ok) { eval("BEGIN{throw:ok,true}; #{@buffer}") }
  rescue SyntaxError
    false
  end

  def consume
    value = eval("_ = (#{@buffer})", @binding, @name, @bufferline)
    @inspector.call self, value
  rescue Exception => exception
    notify_exception(exception)
  ensure
    clear
  end

  def notify_exception(exception)
    notify "#{exception.class.inspect}: #{exception.message}"
    notify *exception.backtrace.map { |t| FROM + t }
  end

  def results(*args)
    args.each do |arg|
      prompt :result, @inputline - 1
      puts arg
    end
  end

  def notify(*args)
    args.each do |arg|
      prompt :notify, @inputline - 1
      puts arg
    end
  end

  def interrupt
    puts if @options[:puts_on_interrupt]
    clear if @options[:clear_on_interrupt]
    prompt
  end

  def clear
    @bufferline = @inputline
    @prompt = :normal
    @buffer = ''
  end

  def print(*args)
    @output.print(*args)
  end

  def puts(*args)
    @output.puts(*args)
  end

  # Immediately load  irbrc
  def self.irbrc
    home = ENV['HOME']
    home ||= ENV['HOMEDRIVE'] + ENV['HOMEPATH']
    rc = "#{home}/.irbrc"
    Kernel.load rc if File.exists?(rc)
  end
end