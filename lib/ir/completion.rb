# Stolen, refactored, abused, from irb.
#
# Original notice:
#
#   irb/completor.rb -
#   	$Release Version: 0.9$
#   	$Revision$
#   	by Keiju ISHITSUKA(keiju@ishitsuka.com)
#       From Original Idea of shugo@ruby-lang.org
#

class Ir
  class Completion
    ReservedWords = [
      "BEGIN", "END", "alias", "and", "begin", "break", "case", "class",
      "def", "defined", "do", "else", "elsif", "end", "ensure", "false",
      "for", "if", "in", "module", "next", "nil", "not", "or", "redo",
      "rescue", "retry", "return", "self", "super", "then", "true", "undef",
      "unless", "until", "when", "while", "yield",
    ]

    Operators = [
      "%", "&", "*", "**", "+", "-", "/", "<", "<<", "<=", "<=>", "==", "===",
      "=~", ">", ">=", ">>", "[]", "[]=", "^", "!", "!=", "!~"
    ]

    REGEXP                             = /^(\/[^\/]*\/)\.([^.]*)$/
    ARRAY                              = /^([^\]]*\])\.([^.]*)$/
    PROC_OR_HASH                       = /^([^\}]*\})\.([^.]*)$/
    SYMBOL                             = /^(:[^:.]*)$/
    ABSOLUTE_CONSTANT_OR_CLASS_METHODS = /^::([A-Z][^:\.\(]*)$/
    CONSTANT_OR_CLASS_METHODS          = /^(((::)?[A-Z][^:.\(]*)+)::?([^:.]*)$/
    SYMBOL_CALL                        = /^(:[^:.]+)\.([^.]*)$/
    NUMERIC                            = /^(-?(0[dbo])?[0-9_]+(\.[0-9_]+)?([eE]-?[0-9]+)?)\.([^.]*)$/
    NUMERIC_HEX                        = /^(-?0x[0-9a-fA-F_]+)\.([^.]*)$/
    GLOBAL                             = /^(\$[^.]*)$/
    VARIABLE                           = /^((\.?[^.]+)+)\.([^.]*)$/
    UNKNOWN                            = /^\.([^.]*)$/

    attr_reader :bind

    def initialize(bind)
      @bind = bind
    end

    def complete(input)
      case input
      when REGEXP
        select_message($1, Regexp.quote($2), col(Regexp.instance_methods))

      when ARRAY
        select_message($1, Regexp.quote($2), col(Array.instance_methods))

      when PROC_OR_HASH
        candidates = col(Proc.instance_methods) | col(Hash.instance_methods)
        select_message($1, Regexp.quote($2), candidates)

      when SYMBOL
        return [] unless Symbol.respond_to?(:all_symbols)
        candidates = Symbol.all_symbols.collect{|s| ":" + s.id2name}
        candidates.grep(/^#{$1}/)

      when ABSOLUTE_CONSTANT_OR_CLASS_METHODS
        candidates = col(Object.constants)
        candidates.grep(/^#{$1}/).collect{|e| "::" + e}

      when CONSTANT_OR_CLASS_METHODS
        receiver = $1
        candidates = begin
          col(eval("#{receiver}.constants", bind)) | eval_methods(receiver)
        rescue Exception
          []
        end
        candidates.grep(/^#{Regexp.quote($4)}/).map{|e| receiver + "::" + e}

      when SYMBOL_CALL
        select_message($1, Regexp.quote($2), col(Symbol.instance_methods))

      when NUMERIC
        select_message($1, Regexp.quote($5), eval_methods(receiver))

      when NUMERIC_HEX
        select_message($1, Regexp.quote($2), eval_methods(receiver))

      when GLOBAL
        regmessage = Regexp.new(Regexp.quote($1))
        candidates = col(global_variables).grep(regmessage)

      when VARIABLE
        receiver = $1
        message = Regexp.quote($3)
        gv = col(eval("global_variables", bind))
        lv = col(eval("local_variables", bind))
        cv = col(eval("self.class.constants", bind))

        candidates = if (gv | lv | cv).include?(receiver)
          # foo.func and foo is local var.
          eval_methods(receiver)
        elsif /^[A-Z]/ =~ receiver and /\./ !~ receiver
          # Foo::Bar.func
          eval_methods(receiver)
        else
          # func1.func2
          candidates = []
          ObjectSpace.each_object(Module){|m|
            name = begin; m.name; rescue Exception; ''; end
            candidates.concat col(m.instance_methods(false))
          }
          candidates.sort!
          candidates.uniq!
        end
        select_message(receiver, message, candidates)

      when UNKNOWN
        select_message("", Regexp.quote($1), col(String.instance_methods(true)))

      else
        candidates = col(eval(<<-RUBY, bind))
        methods | private_methods | local_variables | self.class.constants
        RUBY

        (candidates|ReservedWords).grep(/^#{Regexp.quote(input)}/)
      end
    end
    alias call complete

    def eval_methods(receiver)
      col eval(receiver, bind).methods
    rescue Exception
      []
    end

    def col(enum)
      enum.collect { |m| m.to_s }
    end

    def select_message(receiver, message, candidates)
      cands = candidates.grep(/^#{message}/)
      cands.collect {|e| "#{receiver}.#{e}" if e =~ /^[a-zA-Z_]/ }
    end
  end
end