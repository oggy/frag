require 'tempfile'
require 'fileutils'
require 'optparse'

module Frag
  class App
    def initialize(args, input=STDIN, output=STDOUT, error=STDERR)
      @input, @output, @error = input, output, error
      @status = 0

      beginning = 'frag:'
      ending = 'frag end'
      leader = '#'
      trailer = ''
      @backup_prefix = @backup_suffix = nil

      parser = OptionParser.new do |parser|
        parser.banner = "USAGE: #$0 [options] file ..."

        parser.on '-b', '--begin DELIMITER' do |value|
          beginning = Regexp.escape(value)
        end
        parser.on '-e', '--end DELIMITER' do |value|
          ending = Regexp.escape(value)
        end
        parser.on '-l', '--leader STRING' do |value|
          leader = Regexp.escape(value)
        end
        parser.on '-t', '--trailer STRING' do |value|
          trailer = Regexp.escape(value)
        end
        parser.on '-p', '--backup-prefix PREFIX' do |value|
          @backup_prefix = value
        end
        parser.on '-s', '--backup-suffix SUFFIX' do |value|
          @backup_suffix = value
        end
      end

      parser.parse!(args)
      args.size > 0 or
        return error "no files given"

      @begin_line = Regexp.new(['^', leader, beginning, '(.*)', trailer, '$'].reject(&:empty?).join('\\s*'))
      @end_line = Regexp.new(['^', leader, ending, trailer, '$'].reject(&:empty?).join('\\s*'))
      @input_paths = args
    end

    def run
      return @status if @status != 0
      @input_paths.each do |input_path|
        manage_files(input_path) do |input, output|
          process(input, output)
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
      File.exist?(input_path) or
        return error "file not found: #{input_path}"
      File.file?(input_path) or
        return error "not a file: #{input_path}"
      File.readable?(input_path) or
        return error "cannot open file: #{input_path}"
      tempfile = nil
      success = nil
      open(input_path) do |input|
        tempfile = Tempfile.open('frag') do |output|
          yield input, output or
            return
          output
        end
      end
      if @backup_prefix || @backup_suffix
        backup_path = "#{@backup_prefix}#{File.expand_path(input_path)}#{@backup_suffix}"
        FileUtils.mkdir_p File.dirname(backup_path)
        FileUtils.cp input_path, backup_path
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
          command = $1
          region_start = input.lineno
        when @end_line
          region_start or
            return error "#{input.lineno}: unmatched begin delimiter"
          output.puts `#{command}`
          if !$?.success?
            return error "#{region_start}: failed: (#{$?.exitstatus}) #{command}"
          end
          region_start = nil
          output.puts line
        end
      end
      if region_start
        return error "#{region_start}: unmatched end delimiter"
      end
      true
    end
  end
end
