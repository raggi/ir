class Ir
  autoload :Tty, 'ir/tty'
  autoload :Readline, 'ir/readline'
  autoload :Completion, 'ir/completion'

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
  end

  # Lines are expected to include the \n
  def <<(data)
    @buffer << data
    @inputline += data.count(@term)
    syntax? ? consume : @prompt = :syntax
  end

  def syntax?
    catch(:ok) { eval("BEGIN{throw:ok,true}; #{@buffer}") }
  rescue SyntaxError
    false
  end

  def consume
    value = eval("_ = (#{@buffer})", @binding, @name, @bufferline)
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
    case prompt
    when String
      prompt
    when Proc
      prompt.call(@name, lineno, name)
    else
      prompt.to_s
    end
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
    @output.puts(*args)
  end

  # Immediately load irbrc
  def self.irbrc
    rc = "#{user_home}/.irbrc"
    Kernel.load rc if File.exists?(rc)
  end
  
  def self.user_home
    ENV['HOME'] || ENV['HOMEDRIVE'] + ENV['HOMEPATH']
  end
end