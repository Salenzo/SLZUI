#coding:utf-8
require 'json'
# JS ON!

a = JSON.parse(File.read("example.json"), symbolize_names: true)

# Object names should contain only uppercase letters.

class JSEmitter
  attr_accessor :objects
  def initialize(file = $stdout)
    @file = file
  end
  def emit(a)
    return if a[:disabled]
    case a[:type].to_sym
    when :Scope
      e = JSEmitter.new(@file)
      e.objects = @objects.merge(a[:objects])
      @file.puts "{"
      a[:objects].each do |key, a|
        if a[:type].to_sym == :Variable
          @file.print "var "
          e.emit(a)
          @file.print ";"
        end
      end
      @file.puts unless a[:objects].empty?
      a[:value].each do |a|
        e.emit(a)
        @file.puts ";"
      end
      @file.print "}"
    when :ObjectReference
      emit(@objects[a[:value].to_sym])
    when :Integer32
      @file.print a[:value]
    when :String
      @file.print JSON.generate(a[:value])
    when :Variable
      name = @objects.key(a)&.to_s
      name ||= "random_#{rand(1000)}"
      @file.print "a_#{name}"
    when :FunctionCall
      case a[:head].to_sym
      when :Instruction_NoOperation
        # do nothing
      when :Instruction_Assign
        @file.print "("
        emit a[:arguments][:lhs]
        @file.print ")=("
        emit a[:arguments][:rhs]
        @file.print ")"
      when :Instruction_Write
        @file.print "console.log("
        emit a[:arguments][:value]
        @file.print ")"
      when :Expression_Divide, :Expression_LessEqual, :Expression_Equal, :Expression_Modulo, :Expression_Add, :Expression_Greater
        op = {
          :Expression_Divide => "/",
          :Expression_LessEqual => "<=",
          :Expression_Equal => "===",
          :Expression_Modulo => "%",
          :Expression_Add => "+",
          :Expression_Greater => ">",
        }[a[:head].to_sym]
        @file.print "Math.floor" if a[:head].to_sym == :Expression_Divide
        @file.print "(("
        emit a[:arguments][:lhs]
        @file.print ")#{op}("
        emit a[:arguments][:rhs]
        @file.print "))"
      when :Instruction_Loop
        @file.print "for (;;)"
        emit a[:arguments][:body]
      when :Instruction_Exit
        @file.print({
          "loop" => "break",
          "function" => "return",
          "program" => "require('os').exit()",
        }[a[:arguments][:level]])
      when :Instruction_Conditional
        if a[:arguments][:body]
          @file.print "if ("
          emit a[:arguments][:condition]
          @file.print ")"
          emit a[:arguments][:body]
        end
        if a[:arguments][:else]
          @file.print "if (!("
          emit a[:arguments][:condition]
          @file.print "))"
          emit a[:arguments][:else]
        end
      else
        puts "ERROR: FunctionCall #{a[:head]}"
        exit
      end
    else
      puts "ERROR: #{a[:type]}"
      exit
    end
    @file.print "/* #{a[:comment].gsub("*/", "* /")} */" if a[:comment]
  end
end


f = File.open("DELETE-ME.js", "w")
e = JSEmitter.new(f)
e.objects = {}
e.emit(a)
f.close
puts File.read("DELETE-ME.js")
puts "---"
system "node", "DELETE-ME.js"
File.unlink("DELETE-ME.js")
