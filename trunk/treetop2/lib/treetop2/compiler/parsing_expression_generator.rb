module Treetop2
  module Compiler
    module ParsingExpressionGenerator
      attr_reader :address, :builder, :subexpression_address, :var_symbols
    
      def compile(address, builder)
        @address = address
        @builder = builder
      end
    
      def use_vars(*var_symbols)
        @var_symbols = var_symbols
        builder << var_initialization
      end
    
      def result_var
        var(:result)
      end
    
      def accumulator_var
        var(:accumulator)
      end
    
      def nested_results_var
        var(:nested_results)
      end
    
      def start_index_var
        var(:start_index)
      end
    
      def subexpression_result_var
        "r#{subexpression_address}"
      end
    
      def subexpression_success?
        subexpression_result_var + ".success?"
      end
    
      def obtain_new_subexpression_address
        @subexpression_address = builder.next_address
      end
    
      def accumulate_nested_result
        builder.accumulate nested_results_var, subexpression_result_var
      end
    
      def accumulate_subexpression_result
        builder.accumulate accumulator_var, subexpression_result_var
      end
    
      def assign_result(value_ruby)
        builder.assign result_var, value_ruby
      end
    
      def reset_index
        builder.assign 'self.index', start_index_var
      end
      
      def epsilon_node
        "SyntaxNode.new(input, index...index, #{subexpression_result_var}.nested_failures)"
      end
    
      def var_initialization
        left, right = [], []
        var_symbols.each do |symbol|
          if init_value(symbol)
            left << var(symbol)
            right << init_value(symbol)
          end
        end
        if left.empty?
          ""
        else
          left.join(', ') + ' = ' + right.join(', ')
        end
      end
    
      def var(var_symbol)
        case var_symbol
        when :result then "r#{address}"
        when :accumulator then "s#{address}"
        when :nested_results then "nr#{address}"
        when :start_index then "i#{address}"
        else raise "Unknown var symbol #{var_symbol}."
        end
      end
    
      def init_value(var_symbol)
        case var_symbol
        when :accumulator, :nested_results then '[]'
        when :start_index then 'index'
        else nil
        end
      end
      
      def begin_comment(expression)
        builder << "# begin #{on_one_line(expression)}"
      end
      
      def end_comment(expression)
        builder << "# end #{on_one_line(expression)}"
      end
      
      def on_one_line(expression)
        expression.text_value.tr("\n", ' ')
      end
    end
  end
end