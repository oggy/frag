require 'tempfile'
require 'fileutils'
require 'optparse'
require 'shellwords'

module Frag
  class App
    def initialize(args, input=STDIN, output=STDOUT, error=STDERR)
      @input, @output, @error = input, output, error
      @status = 0

      @state = State.new('frag:', 'frag end', '#', '', nil, nil)

      parser.parse!(args)
      args.size > 0 or
        return error "no files given"

      @input_paths = args
    end

    def run
      return @status if @status != 0
      global_state = @state.dup
      @input_paths.each do |input_path|
        @state = global_state.dup
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

    def parser
      @parser ||= OptionParser.new do |parser|
        parser.banner = "USAGE: #$0 [options] file ..."
        parser.separator "\nOptions:"

        parser.on '-b', '--begin DELIMITER', "Delimiter that begins each generated fragment. Default: 'frag:'" do |value|
          @state.beginning = value
        end
        parser.on '-e', '--end DELIMITER', "Delimiter that ends each generated fragment. Default: 'frag end'" do |value|
          @state.ending = value
        end
        parser.on '-l', '--leader STRING', "String that preceeds each begin or end delimiter. Default: '#'" do |value|
          @state.leader = value
        end
        parser.on '-t', '--trailer STRING', "String that succeeds each begin or end delimiter. Default: ''" do |value|
          @state.trailer = value
        end
        parser.on '-p', '--backup-prefix PREFIX', "Back up original files with the given prefix. May be a directory." do |value|
          @state.backup_prefix = value
        end
        parser.on '-s', '--backup-suffix SUFFIX', "Back up original files with the given suffix." do |value|
          @state.backup_suffix = value
        end

        parser.separator <<-EOS.gsub(/^ *\|/, '')
          |
          |Embedding options:
          |
          |Options may also be embedded in the file itself via a line that
          |contains "$frag-config:". Example:
          |
          |    <!-- $frag-config: -p ~/.frag-backups/ -->
          |
          |Note that the leader and trailer are always taken from the strings
          |that preceed the "$frag-config" and succeed the last option
          |respectively. They need not be set with --leader and --trailer.
          |
        EOS

        def parser.parse_subconfig!(args)
          # OptionParser will error on an argument like like "-->".
          if args.last =~ /\A--?(?:\W|\z)/
            last_arg = args.pop
            parse!(args)
            args << last_arg
          else
            parse!(args)
          end
        end
      end
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
      if @state.backup_prefix || @state.backup_suffix
        backup_path = "#{@state.backup_prefix}#{File.expand_path(input_path)}#{@state.backup_suffix}"
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
        when @state.begin_line
          region_start.nil? or
            return error "#{input.lineno}: nested region"
          command = $1
          region_start = input.lineno
        when @state.end_line
          region_start or
            return error "#{input.lineno}: unmatched end delimiter"
          output.puts `#{command}`
          if !$?.success?
            return error "#{region_start}: failed: (#{$?.exitstatus}) #{command}"
          end
          region_start = nil
          output.puts line
        when /\A\s*(?:(\S+)\s*)?\$frag-config:\s*(.*)$/
          args = Shellwords.shellsplit($2)
          parser.parse_subconfig!(args)
          args.size <= 1 or
            return error "#{input.lineno}: unexpected argument(s): #{args[0..-2].join(' ')}"
          @state.leader = $1 || ''
          @state.trailer = args.first || ''
        end
      end
      if region_start
        return error "#{region_start}: unmatched begin delimiter"
      end
      true
    end
  end

  class State
    def initialize(beginning, ending, leader, trailer, backup_prefix, backup_suffix)
      @beginning = beginning
      @ending = ending
      @leader = leader
      @trailer = trailer
      @backup_prefix = backup_prefix
      @backup_suffix = backup_suffix
    end

    attr_reader :beginning, :ending, :leader, :trailer, :backup_prefix, :backup_suffix

    def beginning=(value)
      @beginning = value
      @begin_line = nil
    end

    def ending=(value)
      @ending = value
      @end_line = nil
    end

    def leader=(value)
      @leader = value
      @begin_line = @end_line = nil
    end

    def trailer=(value)
      @trailer = value
      @begin_line = @end_line = nil
    end

    attr_writer :backup_prefix, :backup_suffix

    def begin_line
      @begin_line ||= build_begin_line
    end

    def end_line
      @end_line ||= build_end_line
    end

    def build_begin_line
      leader = Regexp.escape(@leader)
      beginning = Regexp.escape(@beginning)
      trailer = Regexp.escape(@trailer)
      @begin_line = Regexp.new(['^', leader, beginning, '(.*)', trailer, '$'].reject(&:empty?).join('\\s*'))
    end

    def build_end_line
      leader = Regexp.escape(@leader)
      ending = Regexp.escape(@ending)
      trailer = Regexp.escape(@trailer)
      @end_line = Regexp.new(['^', leader, ending, trailer, '$'].reject(&:empty?).join('\\s*'))
    end
  end
end
