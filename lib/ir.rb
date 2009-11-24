class Ir
  autoload :Tty, 'ir/tty'
  autoload :Readline, 'ir/readline'
  autoload :Completion, 'ir/completion'
  autoload :SocketReadline, 'ir/socket_readline'
  autoload :Test, 'ir/test'

  FROM = "\tfrom "
  CR = "\r"

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
    :prompt_carriage_return => true,
    :prompts => PROMPTS[:complex],
    :inspector => lambda { |ir, o| ir.results o.inspect }
  }

  attr_accessor :prompt
  attr_reader :options

  def initialize(options = {})
    @options = DEFAULTS.merge(options)
    @prompts, @output, @name = @options.values_at(:prompts, :output, :name)
    @inspector, @binding = @options.values_at(:inspector, :binding)
    @term = @options[:term]
    @buffer, @bufferline, @inputline, @prompt = '', 1, 1, :normal
    # So runtimes can do: Thread.current[:ir].notify "OHAI"
    Thread.current[@options[:thread_local_var]] = self
  end

  # Lines are expected to include the \n
  def <<(data)
    @buffer << data
    @inputline += data.count(@term)
    syntax? ? consume : @prompt = :syntax
  end

  def syntax?
    catch(:ok) { eval("BEGIN{throw:ok,true}; _ = #{@buffer}") }
  rescue SyntaxError
    false
  end

  def consume
    value = eval("_ = #{@buffer}", @binding, @name, @bufferline)
    @inspector.call self, value
  rescue SystemExit
    raise
  rescue Exception => exception
    notify_exception(exception)
  ensure
    clear
  end

  def prompt(name = nil, lineno = nil)
    lineno ||= @inputline
    name ||= @prompt
    prompt = @prompts[name]
    s = case prompt
    when String
      prompt
    when Proc
      prompt.call(@name, lineno, name)
    else
      prompt.to_s
    end
    "#{CR if @options[:prompt_carriage_return]}#{s}"
  end

  def notify_exception(exception)
    notify "#{exception.class.inspect}: #{exception.message}"
    notify *exception.backtrace.map { |t| FROM + t }
  end

  def results(*args)
    args.each do |arg|
      print prompt(:result, @inputline - 1)
      puts arg
    end
  end

  def notify(*args)
    args.each do |arg|
      print prompt(:notify, @inputline - 1)
      puts arg
    end
  end

  def interrupt
    puts if @options[:puts_on_interrupt]
    clear if @options[:clear_on_interrupt]
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
    print(args.join(@term), @term)
  end

  # Immediately load irbrc
  def self.irbrc
    rc = "#{user_home}/.irbrc"
    Kernel.load rc if File.exists?(rc)
  rescue
    warn "Error while loading #{rc}:"
    warn "#{$!.message} (#{$!.class})\n\t#{$!.backtrace.join("\n\t")}"
  end
  
  def self.user_home
    ENV['HOME'] || ENV['HOMEDRIVE'] + ENV['HOMEPATH']
  end
end