require 'ruby_parser'
require 'exception_string'

class Ir
  PROMPTS = {
    :normal => ">> ",
    :syntax => " > "
  }
  BLOCK_SIZE = 16*1024

  attr_accessor :name
  attr_accessor :input, :output, :binding

  def initialize(input = $stdin, output = $stdout, binding = TOPLEVEL_BINDING)
    @input, @output = input, output
    @binding = binding
    @name = "(ir)"
    @input_closed = @input.closed?
    @prompt = :normal
    @buffer = ''
  end

  def load_irbrc
    home = ENV['HOME']
    home ||= ENV['HOMEDRIVE'] + ENV['HOMEPATH']
    rc = "#{home}/.irbrc"
    Kernel.load rc if File.exists?(rc)
  end

  def loop
    while !@input_closed
      crank
    end
  end
  alias start loop

  def crank
    print_prompt
    read_input
    syntax? ? execute : @prompt = :syntax
  end

  def print_prompt
    @output.print PROMPTS[@prompt]
    @output.flush
  end

  def read_input
    @buffer << @input.readpartial(BLOCK_SIZE)
  rescue Interrupt
    @output.puts
    clear
  rescue EOFError
    @output.puts
    exit if @output.tty?
    @input_closed = true if @input.closed?
  end

  def syntax?
    RubyParser.new.parse(@buffer)
    true
  rescue Racc::ParseError
    false
  rescue SyntaxError
    puts $!.message
    clear
    false
  end

  def execute
    @output.puts "=> #{eval(@buffer, @binding, @name).inspect}"
  rescue SystemExit
    raise
  rescue Exception
    @output.puts $!.to_s_mri
  ensure
    clear
  end

  def clear
    @prompt = :normal
    @buffer = ''
  end

end