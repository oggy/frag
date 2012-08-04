require 'tempfile'
require 'fileutils'

module Frag
  class App
    def initialize(args, input=STDIN, output=STDOUT, error=STDERR)
      @input, @output, @error = input, output, error
      @status = 0
      @begin_line = /^\s*#\s*GEN:/
      @end_line = /^\s*#\s*ENDGEN\s*$/

      parser = OptionParser.new do |parser|
        parser.banner = "USAGE: #$0 [options] file ..."
      end

      parser.parse!(args)
      args.size > 0 or
        return error "no files given"
      @input_paths = args
    end

    def run
      return @status if @status != 0
      @input_paths.each do |input_path|
        manage_files(input_path) do |input, output|
          process(input, output) or
            return @status
        end
      end
      @status
    end

    attr_reader :status

    private

    def error(message, status=1)
      @error.puts "error: #{message}"
      @status = status
      false
    end

    def manage_files(input_path)
      tempfile = nil
      open(input_path) do |input|
        tempfile = Tempfile.open('frag') do |output|
          yield input, output
          output
        end
      end
      FileUtils.cp tempfile.path, input_path
    end

    def process(input, output)
      region_start = nil
      command = nil
      while (line = input.gets)
        unless region_start
          output.puts line
        end
        case line
        when @begin_line
          region_start.nil? or
            return error "#{input.lineno}: nested region"
          command = $'.strip
          region_start = input.lineno
        when @end_line
          output.puts `#{command}`
          if !$?.success?
            return error "#{region_start}: failed: (#{$?.exitstatus}) #{command}"
          end
          region_start = nil
          output.puts line
        end
      end
      if region_start
        return error "#{region_start}: unmatched delimiter"
      end
      true
    end
  end
end
