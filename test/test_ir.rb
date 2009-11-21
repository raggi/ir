begin
  require 'test/unit'
rescue LoadError, Exception
  e = $!
  begin
    require "minitest/autorun"
  rescue LoadError
    abort "tests require test-unit or minitest, exceptions:"
    # maglev debugging...
    p e.message
    p $!.message
  end
end
require 'stringio'

require "ir"

TC = defined?(Test::Unit::TestCase) ? Test::Unit::TestCase : MiniTest::Unit::TestCase

class TestIr < TC

  attr_reader :output, :ir

  # Old rubies...
  def __method__
    caller[1][/`(.*)'/,1]
  end unless defined?(__method__)
  
  def maglev?
    RUBY_ENGINE == 'maglev'
  end

  def ir_options
    {
      :output => output,
      :prompts => Ir::PROMPTS[:simple],
      :prompt_carriage_return => false
    }
  end

  def setup_ir
    @output = StringIO.new
    @ir = Ir.new(ir_options)
  end

  def setup
    setup_ir
  end

  def test_print
    ir.print('foo bar')
    output.rewind
    assert_equal 'foo bar', output.read
    ir.print(*%w(1 2 3))
    output.rewind
    assert_equal "foo bar123", output.read
  end

  def test_puts
    ir.puts('foo bar')
    output.rewind
    assert_equal "foo bar\n", output.read
    ir.puts(*%w(1 2 3))
    output.rewind
    assert_equal "foo bar\n1\n2\n3\n", output.read
  end

  def test_prompt_simple
    assert_equal ">> ", ir.prompt
    assert_equal ">> ", ir.prompt(:normal)
    assert_equal " > ", ir.prompt(:syntax)
    assert_equal "#> ", ir.prompt(:notify)
    assert_equal "=> ", ir.prompt(:result)
  end

  def test_notify_exception
    l = nil
    begin
      l = __LINE__; raise 'boom'
    rescue
      bt = $!.backtrace.slice(0..2)
      # maglev hax, god i'm lazy.
      class <<$!;self;end.class_eval do
        define_method(:backtrace) { bt }
      end
      ir.notify_exception($!)
    end
    output.rewind
    assert_equal <<-PLAIN.split("\n").map{|l|l.lstrip}.join("\n"), output.read
    #> RuntimeError: boom
    #> \tfrom #{maglev? ? File.expand_path(__FILE__) : __FILE__}:#{l}:in `#{__method__}'
    PLAIN
  end

  def test_results
    ir.results(%w(1 2 3))
    output.rewind
    assert_equal "=> 1\n2\n3\n", output.read
  end

  def test_interrupt
    ir.options[:puts_on_interrupt] = false
    ir.interrupt
    output.rewind
    assert_equal "", output.read
    ir.options[:puts_on_interrupt] = true
    ir.interrupt
    output.rewind
    assert_equal "\n", output.read
    ir.options[:clear_on_interrupt] = false
    ir << 'class A; self; '
    ir.interrupt
    ir << 'end'
    output.rewind
    assert_equal "\n\n=> A\n", output.read
  end

  def test_valid_syntax
    ir << 'class A; self; end'
    output.rewind
    assert_equal "=> A\n", output.read
  end

  def test_incomplete_syntax
    ir << 'class A; self;'
    output.rewind
    assert output.read.empty?
    ir << 'end'
    output.rewind
    assert_equal "=> A\n", output.read
  end

  def test_raise_boom
    ir << 'raise "boom"'
    output.rewind
    assert_equal "#> RuntimeError: boom\n#> \tfrom (ir):1\n", output.read
  end

  def test_does_not_consume_system_exit
    assert_raises(SystemExit) do
      ir << 'exit'
    end
  end

  def test_inspector
    inspector = lambda { |ir, o| ir.puts o.reverse }
    ir = Ir.new(ir_options.merge(:inspector => inspector))
    ir << '"foo"'
    output.rewind
    assert_equal %(oof\n), output.read
  end

  def test_thread_local_var
    assert_equal ir, Thread.current[:ir]
    ir = Ir.new(ir_options.merge(:thread_local_var => :a))
    assert_equal ir, Thread.current[:a]
  end

  def test_name
    ir = Ir.new(ir_options.merge(:name => 'test_ir'))
    ir << 'raise "boom"'
    output.rewind
    assert_equal "#> RuntimeError: boom\n#> \tfrom test_ir:1\n", output.read
  end

  def test_term
    ir = Ir.new(ir_options.merge(:term => '\\'))
    ir << '1'
    output.rewind
    assert_equal "=> 1\\", output.read
  end

  def test_user_home
    temp, ENV['HOME'] = ENV['home'], nil
    ENV['HOMEDRIVE'] ||= 'C:'
    ENV['HOMEPATH'] ||= '\\Users\\raggi'
    assert_equal ENV['HOMEDRIVE'] + ENV['HOMEPATH'], Ir.user_home
    ENV['HOME'] = '/home/raggi'
    assert_equal '/home/raggi', Ir.user_home
  ensure
    ENV['HOME'] = temp
  end

  def test_binding_factory
    flunk 'TODO'
  end

  def test_irrc
    flunk 'using irbrc atm'
  end

end