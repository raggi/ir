require 'readline'

class Ir
  class Readline < Tty
    TERM = "\n"
    DEFAULTS = {
      :term => TERM,
      :history => true,
      :history_file => Ir.user_home + '/.ir_history',
      :history_save => -1,
      # Darwin readline bug!
      # TODO - support native readline build here, more cleanly
      # TODO - really need to check some other platforms for these defaults..
      :puts_on_interrupt => RUBY_PLATFORM !~ /darwin/ || RUBY_VERSION >= '1.9.0'
    }
    havehist = File.exists?(DEFAULTS[:history_file])
    DEFAULTS[:load_history] = DEFAULTS[:save_history] = havehist
    HISTORY_UNIQ_REQUIREMENTS = %w(find_index delete_at push)

    def self.support_history_uniq?
      HISTORY_UNIQ_REQUIREMENTS.all? { |r| ::Readline::HISTORY.respond_to? r }
    end
    DEFAULTS[:history_uniq] = support_history_uniq?

    def initialize(input = $stdin, output = $stdout, options = {})
      @options = DEFAULTS.merge(options)
      ::Readline.input = input if ::Readline.respond_to?(:input=)
      ::Readline.output = output if ::Readline.respond_to?(:output=)
      @history = @options[:history]

      @history_uniq = if @options[:history_uniq]
        unless self.class.support_history_uniq?
          raise ArgumentError, "History not supported on this platform"
        end
        true
      else
        false
      end

      load_history if @options[:load_history]
      super(input, output, @options)
    end

    def consume
      exit_on_eof do
        interruptable do
          if line = ::Readline.readline(@ir.prompt, @history && !@history_uniq)
            if @history_uniq
              idx = history.find_index(line)
              history.delete_at(idx) if idx
              history.push(line) unless line.empty?
            end
            @ir << line + TERM
          else
            raise EOFError
          end
        end while true
      end
    ensure
      save_history if @options[:save_history]
    end

    def history
      ::Readline::HISTORY
    end

    def save_history
      open(@options[:history_file], 'w') do |f|
        f.puts *history.to_a.reverse[0..@options[:history_save]].reverse
      end
    end

    def load_history
      history = []
      open(@options[:history_file]) do |f|
        f.each_line do |line|
          history << line.chomp
        end
      end
      history.uniq! if @history_uniq
      ::Readline::HISTORY.push *history
    end

  end
end