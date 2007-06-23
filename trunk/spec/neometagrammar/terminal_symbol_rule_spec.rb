dir = File.dirname(__FILE__)
require "#{dir}/../spec_helper"
require "#{dir}/metagrammar_spec_context_helper"

describe "The node returned by the terminal_symbol rule's successful parsing of a single-quoted string" do
  include MetagrammarSpecContextHelper
  
  before(:all) do
    with_metagrammar(:terminal_symbol) do |parser|
      @node = parser.parse("'foo'")
    end
  end
  
  it "is successful" do
    @node.should be_success
  end

  it "has a Ruby source representation that evaluates to TerminalSymbol with the correct prefix" do
    value = eval(@node.to_ruby)
    value.should be_an_instance_of(TerminalSymbol)
    value.prefix.should == 'foo'
  end
end

describe "The node returned by the terminal_symbol rule's successful parsing of a single-quoted string followed by a Ruby block" do
  include MetagrammarSpecContextHelper
  
  before(:all) do
    with_metagrammar(:terminal_symbol) do |parser|
      @node = parser.parse("'foo' {\ndef a_method\n\nend\n}")
    end
  end

  it "is successful" do
    @node.should be_success
  end

  it "has a Ruby source representation that evaluates to TerminalSymbol with the method in the block defined on it" do
    value = eval(@node.to_ruby)
    value.should be_an_instance_of(TerminalSymbol)    
    value.node_class.instance_methods.should include('a_method')
  end
end

describe "The node returned by the terminal_symbol rule's successful parsing of a double-quoted string" do
  include MetagrammarSpecContextHelper

  before(:all) do
    with_metagrammar(:terminal_symbol) do |parser|
      @node = parser.parse('"foo"')
    end
  end
  
  it "is successful" do
    @node.should be_success
  end

  it "has a Ruby source representation that evaluates to TerminalSymbol with the correct prefix" do
    value = eval(@node.to_ruby)
    value.should be_an_instance_of(TerminalSymbol)
    value.prefix.should == 'foo'
  end
end

describe "The node returned by the terminal_symbol rule's successful parsing of a single quote in double quotes" do
  include MetagrammarSpecContextHelper

  before(:all) do
    with_metagrammar(:terminal_symbol) do |parser|
      @node = parser.parse("\"'\"")
    end
  end
  
  it "is successful" do
    @node.should be_success
  end
  
  it "has a Ruby source representation that evaluates to TerminalSymbol with the correct prefix" do
    value = eval(@node.to_ruby)
    value.should be_an_instance_of(TerminalSymbol)
    value.prefix.should == "'"
  end
end

describe "The node returned by the terminal_symbol rule's successful parsing of an escaped single quote in single quotes" do
  include MetagrammarSpecContextHelper

  before(:all) do
    with_metagrammar(:single_quoted_string) do |parser|
      @node = parser.parse("'\\''")
    end
  end

  it "is successful" do
    @node.should be_success
  end
  
  it "has a Ruby source representation that evaluates to TerminalSymbol with the correct prefix" do
    value = eval(@node.to_ruby)
    value.should be_an_instance_of(TerminalSymbol)
    value.prefix.should == "'"
  end  
end

describe "The node returned by the terminal_symbol rule's successful parsing of a double-quoted string followed by a Ruby block" do
  include MetagrammarSpecContextHelper
  
  before(:all) do
    with_metagrammar(:terminal_symbol) do |parser|
      @node = parser.parse("\"foo\" {\ndef a_method\n\nend\n}")
    end
  end

  it "is successful" do
    @node.should be_success
  end

  it "has a Ruby source representation that evaluates to TerminalSymbol with the method in the block defined on it" do
    value = eval(@node.to_ruby)
    value.should be_an_instance_of(TerminalSymbol)    
    value.node_class.instance_methods.should include('a_method')
  end
end