module Treetop2
  module Compiler2
    
    module AtomicExpression
      def inline_modules
        []
      end
    end
    
    class TreetopFile < Parser::SyntaxNode
      def compile
        (elements.map {|elt| elt.compile}).join
      end
    end
    
    class Grammar < Parser::SyntaxNode
      def compile
        builder = RubyBuilder.new
        
        builder << "class #{grammar_name.text_value} < ::Treetop2::Parser::CompiledParser"
        builder.indented do
          builder << "include ::Treetop2::Parser"
          parsing_rule_sequence.compile(builder)
        end
        builder << "end"
      end
    end
    
    class ParsingRuleSequence < Parser::SyntaxNode
      def compile(builder)
        builder << "def root"
        builder.indented do
          builder << rules.first.method_name
        end
        builder << "end"
        
        rules.each { |rule| rule.compile(builder) }
      end
    end

    class ParsingRule < Parser::SyntaxNode
      def compile(builder)
        compile_inline_module_declarations(builder)
        builder.reset_addresses
        expression_address = builder.next_address
        builder << "def #{method_name}"
        builder.indented do
          parsing_expression.compile(expression_address, builder)
          builder << "return r#{expression_address}"
        end
        builder << "end"
      end
      
      def compile_inline_module_declarations(builder)
        parsing_expression.inline_modules.each_with_index do |inline_module, i|
          inline_module.compile(i, self, builder)
        end
      end
      
      def method_name
        "_nt_#{name}"
      end
      
      def name
        nonterminal.text_value
      end
    end
    
    class ParenthesizedExpression < Parser::SyntaxNode
      def compile(address, builder, parent_expression = nil)
        elements[2].compile(address, builder)
      end
    end
    
    class Nonterminal < Parser::SyntaxNode
      include ParsingExpression
      include AtomicExpression
      
      def compile(address, builder, parent_expression = nil)
        super
        use_vars :result
        assign_result "self.send(:_nt_#{text_value})"
      end
    end
    
    class Terminal < Parser::SyntaxNode
      include ParsingExpression
      include AtomicExpression
      
      def compile(address, builder, parent_expression = nil)
        super
        assign_result "parse_terminal(#{text_value}, #{node_class}#{optional_arg(inline_module_name)})"
      end
    end
    
    class AnythingSymbol < Parser::SyntaxNode
      include ParsingExpression
      include AtomicExpression
      
      def compile(address, builder, parent_expression = nil)
        super
        assign_result "parse_anything(#{node_class}#{optional_arg(inline_module_name)})"
      end
    end
    
    class CharacterClass < Parser::SyntaxNode
      include ParsingExpression
      include AtomicExpression
      
      def compile(address, builder, parent_expression = nil)
        super
        assign_result "parse_char_class(/#{text_value}/, '#{elements[1].text_value.gsub(/'$/, "\\\\'")}', #{node_class}#{optional_arg(inline_module_name)})"
      end
    end
    
    class Sequence < Parser::SyntaxNode
      include ParsingExpression
      
      def compile(address, builder, parent_expression = nil)
        super
        begin_comment(self)
        use_vars :result, :start_index, :accumulator, :nested_results
        compile_sequence_elements(sequence_elements)
        builder.if__ "#{accumulator_var}.last.success?" do
          assign_result "(#{node_class_declarations.node_class}).new(input, #{start_index_var}...index, #{accumulator_var})"
          builder << "#{result_var}.extend(#{inline_module_name})" if inline_module_name
        end
        builder.else_ do
          reset_index
          assign_result "ParseFailure.new(#{start_index_var}, #{accumulator_var})"
        end
        end_comment(self)
      end
      
      def compile_sequence_elements(elements)
        obtain_new_subexpression_address
        elements.first.compile(subexpression_address, builder)
        accumulate_subexpression_result
        if elements.size > 1
          builder.if_ subexpression_success? do
            compile_sequence_elements(elements[1..-1])
          end
        end
      end
    end
    
    class Choice < Parser::SyntaxNode
      include ParsingExpression
      
      def compile(address, builder, parent_expression = nil)
        super
        begin_comment(self)
        use_vars :result, :start_index, :nested_results
        compile_alternatives(alternatives)
        end_comment(self)
      end
      
      def compile_alternatives(alternatives)
        obtain_new_subexpression_address
        alternatives.first.compile(subexpression_address, builder)
        accumulate_nested_result
        builder.if__ subexpression_success? do
          assign_result subexpression_result_var
          builder << "#{subexpression_result_var}.update_nested_results(#{nested_results_var})"
        end
        builder.else_ do
          if alternatives.size == 1
            reset_index
            assign_result "ParseFailure.new(#{start_index_var}, #{nested_results_var})"
          else
            compile_alternatives(alternatives[1..-1])
          end
        end
      end
    end
    
    
    class Repetition < Parser::SyntaxNode
      include ParsingExpression
      
      def compile(address, builder, parent_expression)
        super
        repeated_expression = parent_expression.atomic
        begin_comment(parent_expression)
        use_vars :result, :accumulator, :nested_results, :start_index

        builder.loop do
          obtain_new_subexpression_address
          repeated_expression.compile(subexpression_address, builder)
          accumulate_nested_result
          builder.if__ subexpression_success? do
            accumulate_subexpression_result
          end
          builder.else_ do
            builder.break
          end
        end
      end
      
      def inline_module_name
        parent_expression.inline_module_name
      end
      
      def assign_and_extend_result
        assign_result "#{node_class}.new(input, #{start_index_var}...index, #{accumulator_var}, #{nested_results_var})"
        builder << "#{result_var}.extend(#{inline_module_name})" if inline_module_name
      end
    end
    
    class ZeroOrMore < Repetition
      def compile(address, builder, parent_expression)
        super
        assign_and_extend_result
        end_comment(parent_expression)
      end
    end
    
    class OneOrMore < Repetition
      def compile(address, builder, parent_expression)
        super
        builder.if__ "#{accumulator_var}.empty?" do
          reset_index
          assign_result "ParseFailure.new(#{start_index_var}, #{nested_results_var})"
        end
        builder.else_ do
          assign_and_extend_result
        end
        end_comment(parent_expression)
      end
    end
    
    class Optional < Parser::SyntaxNode
      include ParsingExpression
      
      def compile(address, builder, parent_expression)
        super
        use_vars :result
        obtain_new_subexpression_address
        parent_expression.atomic.compile(subexpression_address, builder)
        
        builder.if__ subexpression_success? do
          assign_result subexpression_result_var
        end
        builder.else_ do
          assign_result epsilon_node
        end
      end
    end
    
    class Predicate < Parser::SyntaxNode
      include ParsingExpression

      def compile(address, builder, parent_expression)
        super
        begin_comment(parent_expression)
        use_vars :result, :start_index
        obtain_new_subexpression_address
        parent_expression.predicated_expression.compile(subexpression_address, builder)
        builder.if__(subexpression_success?) { when_success }
        builder.else_ { when_failure }
        end_comment(parent_expression)
      end
      
      def assign_failure
        assign_result "ParseFailure.new(#{start_index_var}, #{subexpression_result_var}.nested_failures)"
      end
      
      def assign_success
        reset_index
        assign_result epsilon_node
      end
    end
    
    class AndPredicate < Predicate
      def when_success
        assign_success
      end

      def when_failure
        assign_failure
      end
    end
    
    class NotPredicate < Predicate
      def when_success
        assign_failure
      end
      
      def when_failure
        assign_success
      end
    end
    
    class InlineModule < Parser::SyntaxNode
      attr_reader :module_name
      
      def compile(index, rule, builder)
        @module_name = "#{rule.name.camelize}#{index}"
        builder << "module #{module_name}"
        builder.indented do
          builder << ruby_code
        end
        builder << "end"
      end
      
      def ruby_code
        elements[1].text_value
      end
    end
  end
end