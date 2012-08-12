require_relative '../test_helper'
require 'stringio'
require 'tempfile'

describe Frag::App do
  let(:input) { StringIO.new }
  let(:output) { StringIO.new }
  let(:error) { StringIO.new }

  def frag(*args)
    Frag::App.new(args, input, output, error).run
  end

  describe "when no options are used" do
    it "populates the delimited region if it's empty" do
      write_file 'input', <<-EOS.demargin
        |# frag: echo hi
        |# frag end
      EOS
      frag('input').must_equal 0
      (output.string + error.string).must_equal ''
      File.read('input').must_equal <<-EOS.demargin
        |# frag: echo hi
        |hi
        |# frag end
      EOS
    end

    it "replaces the delimited region if there's already something there" do
      write_file 'input', <<-EOS.demargin
        |# frag: echo new
        |old
        |# frag end
      EOS
      frag('input').must_equal 0
      (output.string + error.string).must_equal ''
      File.read('input').must_equal <<-EOS.demargin
        |# frag: echo new
        |new
        |# frag end
      EOS
    end

    it "appends a newline if the command output doesn't end in one" do
      write_file 'input', <<-EOS.demargin
        |# frag: echo -n hi
        |# frag end
      EOS
      frag('input').must_equal 0
      (output.string + error.string).must_equal ''
      File.read('input').must_equal <<-EOS.demargin
        |# frag: echo -n hi
        |hi
        |# frag end
      EOS
    end

    it "processes multiple regions, and leave surrounding content alone" do
      write_file 'input', <<-EOS.demargin
        |before
        |# frag: echo one
        |# frag end
        |middle
        |# frag: echo two
        |# frag end
        |after
      EOS
      frag('input').must_equal 0
      (output.string + error.string).must_equal ''
      File.read('input').must_equal <<-EOS.demargin
        |before
        |# frag: echo one
        |one
        |# frag end
        |middle
        |# frag: echo two
        |two
        |# frag end
        |after
      EOS
    end

    it "can process multiple files" do
      write_file 'one', <<-EOS.demargin
        |# frag: echo one
        |# frag end
      EOS
      write_file 'two', <<-EOS.demargin
        |# frag: echo two
        |# frag end
      EOS
      frag('one', 'two').must_equal 0
      (output.string + error.string).must_equal ''
      File.read('one').must_equal <<-EOS.demargin
        |# frag: echo one
        |one
        |# frag end
      EOS
      File.read('two').must_equal <<-EOS.demargin
        |# frag: echo two
        |two
        |# frag end
      EOS
    end
  end

  describe "when the delimiter options are used" do
    ['-b', '--begin'].each do |option|
      it "uses the beginning delimiter given by #{option}" do
        write_file 'input', <<-EOS.demargin
          |# BEGIN echo one
          |# frag end
        EOS
        frag(option, 'BEGIN', 'input').must_equal 0
        (output.string + error.string).must_equal ''
        File.read('input').must_equal <<-EOS.demargin
          |# BEGIN echo one
          |one
          |# frag end
        EOS
      end
    end

    ['-e', '--end'].each do |option|
      it "uses the ending delimiter given by #{option}" do
        write_file 'input', <<-EOS.demargin
          |# frag: echo one
          |# END
        EOS
        frag(option, 'END', 'input').must_equal 0
        (output.string + error.string).must_equal ''
        File.read('input').must_equal <<-EOS.demargin
          |# frag: echo one
          |one
          |# END
        EOS
      end
    end

    ['-l', '--leader'].each do |option|
      it "uses the delimiter leader given by #{option}" do
        write_file 'input', <<-EOS.demargin
          |// frag: echo one
          |// frag end
        EOS
        frag(option, '//', 'input').must_equal 0
        (output.string + error.string).must_equal ''
        File.read('input').must_equal <<-EOS.demargin
          |// frag: echo one
          |one
          |// frag end
        EOS
      end
    end

    ['-t', '--trailer'].each do |option|
      it "uses the delimiter trailer given by #{option}" do
        write_file 'input', <<-EOS.demargin
          |# frag: echo one @@
          |# frag end @@
        EOS
        frag(option, '@@', 'input').must_equal 0
        (output.string + error.string).must_equal ''
        File.read('input').must_equal <<-EOS.demargin
          |# frag: echo one @@
          |one
          |# frag end @@
        EOS
      end
    end

    it "supports using delimiter options together" do
      write_file 'input', <<-EOS.demargin
        |/* BEGIN echo one */
        |/* END */
      EOS
      frag('-b', 'BEGIN', '-e', 'END', '-l', '/*', '-t', '*/', 'input').must_equal 0
      (output.string + error.string).must_equal ''
      File.read('input').must_equal <<-EOS.demargin
        |/* BEGIN echo one */
        |one
        |/* END */
      EOS
    end
  end

  describe "when the backup options are used" do
    ['-p', '--backup-prefix'].each do |option|
      it "backs up the input file with the prefix given by #{option}" do
        write_file 'input', <<-EOS.demargin
          |# frag: echo new
          |old
          |# frag end
        EOS
        frag(option, 'path/to/backups', 'input').must_equal 0
        (output.string + error.string).must_equal ''
        File.read('input').must_equal <<-EOS.demargin
          |# frag: echo new
          |new
          |# frag end
        EOS
        File.read("path/to/backups/#{File.expand_path('input')}").must_equal <<-EOS.demargin
          |# frag: echo new
          |old
          |# frag end
        EOS
      end
    end

    ['-s', '--backup-suffix'].each do |option|
      it "backs up the input file with the suffix given by #{option}" do
        write_file 'input', <<-EOS.demargin
          |# frag: echo new
          |old
          |# frag end
        EOS
        frag(option, '.backup', 'input').must_equal 0
        (output.string + error.string).must_equal ''
        File.read('input').must_equal <<-EOS.demargin
          |# frag: echo new
          |new
          |# frag end
        EOS
        File.read('input.backup').must_equal <<-EOS.demargin
          |# frag: echo new
          |old
          |# frag end
        EOS
      end
    end

    it "supports using --backup-prefix and --backup-suffix together" do
      write_file 'input', <<-EOS.demargin
        |# frag: echo new
        |old
        |# frag end
      EOS
      frag('-p', 'path/to/backups', '-s', '.backup', 'input').must_equal 0
      (output.string + error.string).must_equal ''
      File.read('input').must_equal <<-EOS.demargin
        |# frag: echo new
        |new
        |# frag end
      EOS
      File.read("path/to/backups/#{File.expand_path('input')}.backup").must_equal <<-EOS.demargin
        |# frag: echo new
        |old
        |# frag end
      EOS
    end

    it "does not back up files which produce errors" do
      write_file 'a', <<-EOS.demargin
        |# frag: true
        |# frag end
      EOS
      write_file 'b', <<-EOS.demargin
        |# frag: false
        |# frag end
      EOS
      write_file 'c', <<-EOS.demargin
        |# frag: true
        |# frag end
      EOS
      frag('-s', '.backup', 'a', 'b', 'c').must_equal 1
      File.exist?('a.backup').must_equal true
      File.exist?('b.backup').must_equal false
      File.exist?('c.backup').must_equal true
    end
  end

  ['-v', '--version'].each do |option|
    it "prints the version if the #{option} option is given" do
      frag(option).must_equal 0
      output.string.must_equal "Frag version #{Frag::VERSION}\n"
      error.string.must_equal ''
    end
  end

  describe "a $frag-config line" do
    it "honors the --begin option" do
      write_file 'input', <<-EOS.demargin
        |# BEGIN echo one
        |# frag: echo one
        |# frag end
        |# $frag-config: --begin BEGIN
        |# BEGIN echo one
        |# frag: echo one
        |# frag end
      EOS
      frag('input').must_equal 0
      (output.string + error.string).must_equal ''
      File.read('input').must_equal <<-EOS.demargin
        |# BEGIN echo one
        |# frag: echo one
        |one
        |# frag end
        |# $frag-config: --begin BEGIN
        |# BEGIN echo one
        |one
        |# frag end
      EOS
    end

    it "honors the --end option" do
      write_file 'input', <<-EOS.demargin
        |# frag: echo one
        |# END
        |# frag end
        |# $frag-config: --end END
        |# frag: echo one
        |# END
        |# frag end
      EOS
      frag('input').must_equal 0
      (output.string + error.string).must_equal ''
      File.read('input').must_equal <<-EOS.demargin
        |# frag: echo one
        |one
        |# frag end
        |# $frag-config: --end END
        |# frag: echo one
        |one
        |# END
        |# frag end
      EOS
    end

    it "infers the leader and trailer" do
      write_file 'input', <<-EOS.demargin
        |/* frag: echo one */
        |/* frag end */
        |/* $frag-config: */
        |/* frag: echo one */
        |/* frag end */
      EOS
      frag('input').must_equal 0
      (output.string + error.string).must_equal ''
      File.read('input').must_equal <<-EOS.demargin
        |/* frag: echo one */
        |/* frag end */
        |/* $frag-config: */
        |/* frag: echo one */
        |one
        |/* frag end */
      EOS
    end

    it "can nullify the leader and trailer" do
      write_file 'input', <<-EOS.demargin
        |frag: echo one
        |frag end
        |$frag-config:
        |frag: echo one
        |frag end
      EOS
      frag('input').must_equal 0
      (output.string + error.string).must_equal ''
      File.read('input').must_equal <<-EOS.demargin
        |frag: echo one
        |frag end
        |$frag-config:
        |frag: echo one
        |one
        |frag end
      EOS
    end

    it "warns if the leader is set via an option" do
      write_file 'input', <<-EOS.demargin
        |# $frag-config: --leader %
      EOS
      frag('input').must_equal 0
      error.string.must_equal "warning: -l / --leader is unnecessary in $frag-config line\n"
    end

    it "warns if the trailer is set via an option" do
      write_file 'input', <<-EOS.demargin
        |# $frag-config: --trailer %
      EOS
      frag('input').must_equal 0
      error.string.must_equal "warning: -t / --trailer is unnecessary in $frag-config line\n"
    end

    it "handles trailers that start with '-', which can trick optparse" do
      write_file 'input', <<-EOS.demargin
        |<!-- frag: echo one -->
        |<!-- frag end -->
        |<!-- $frag-config: -->
        |<!-- frag: echo one -->
        |<!-- frag end -->
      EOS
      frag('input').must_equal 0
      (output.string + error.string).must_equal ''
      File.read('input').must_equal <<-EOS.demargin
        |<!-- frag: echo one -->
        |<!-- frag end -->
        |<!-- $frag-config: -->
        |<!-- frag: echo one -->
        |one
        |<!-- frag end -->
      EOS
    end

    it "honors the --backup-prefix option" do
      write_file 'input', <<-EOS.demargin
        |# $frag-config: --backup-prefix path/to/backups
        |# frag: echo new
        |old
        |# frag end
      EOS
      frag('input').must_equal 0
      (output.string + error.string).must_equal ''
      File.read('input').must_equal <<-EOS.demargin
        |# $frag-config: --backup-prefix path/to/backups
        |# frag: echo new
        |new
        |# frag end
      EOS
      File.read("path/to/backups/#{File.expand_path('input')}").must_equal <<-EOS.demargin
        |# $frag-config: --backup-prefix path/to/backups
        |# frag: echo new
        |old
        |# frag end
      EOS
    end

    it "honors the --backup-suffix option" do
      write_file 'input', <<-EOS.demargin
        |# $frag-config: --backup-suffix .backup
        |# frag: echo new
        |old
        |# frag end
      EOS
      frag('input').must_equal 0
      (output.string + error.string).must_equal ''
      File.read('input').must_equal <<-EOS.demargin
        |# $frag-config: --backup-suffix .backup
        |# frag: echo new
        |new
        |# frag end
      EOS
      File.read('input.backup').must_equal <<-EOS.demargin
        |# $frag-config: --backup-suffix .backup
        |# frag: echo new
        |old
        |# frag end
      EOS
    end

    it "scopes options to the file it appears in" do
      write_file 'a', <<-EOS.demargin
        |/* $frag-config: -b BEGIN -e END */
        |/* BEGIN echo a */
        |/* END */
      EOS
      write_file 'b', <<-EOS.demargin
        |/* BEGIN echo b */
        |/* END */
        |# frag: echo b
        |# frag end
      EOS
      frag('a', 'b').must_equal 0
      (output.string + error.string).must_equal ''
      File.read('a').must_equal <<-EOS.demargin
        |/* $frag-config: -b BEGIN -e END */
        |/* BEGIN echo a */
        |a
        |/* END */
      EOS
      File.read('b').must_equal <<-EOS.demargin
        |/* BEGIN echo b */
        |/* END */
        |# frag: echo b
        |b
        |# frag end
      EOS
    end

    it "can be used more than once in a file" do
      write_file 'input', <<-EOS.demargin
        |// $frag-config:
        |// frag: echo one
        |// frag end
        |
        |/* $frag-config: */
        |/* frag: echo one */
        |/* frag end */
      EOS
      frag('input', '--trailer', '1').must_equal 0
      (output.string + error.string).must_equal ''
      File.read('input').must_equal <<-EOS.demargin
        |// $frag-config:
        |// frag: echo one
        |one
        |// frag end
        |
        |/* $frag-config: */
        |/* frag: echo one */
        |one
        |/* frag end */
      EOS
    end

    it "errors if there are stray arguments" do
      write_file 'input', <<-EOS.demargin
        |# $frag-config: arg trailer
      EOS
      frag('input').must_equal 1
      (output.string + error.string).must_match /unexpected argument/
    end
  end

  it "prints an error and leaves the input file unchanged if a command fails" do
    write_file 'input', <<-EOS.demargin
      |# frag: echo new
      |old
      |# frag end
      |# frag: false
      |# frag end
    EOS
    frag('input').must_equal 1
    output.string.must_equal ''
    error.string.must_match(/\b4:.*failed/)
    File.read('input').must_equal <<-EOS.demargin
      |# frag: echo new
      |old
      |# frag end
      |# frag: false
      |# frag end
    EOS
  end

  it "prints an error if there's an unmatched beginning line" do
    write_file 'input', <<-EOS.demargin
      |# frag: echo one
    EOS
    frag('input').must_equal 1
    output.string.must_equal ''
    error.string.must_match(/\b1:.*unmatched/)
  end

  it "prints an error if there's an unmatched ending line" do
    write_file 'input', <<-EOS.demargin
      |# frag end
    EOS
    frag('input').must_equal 1
    output.string.must_equal ''
    error.string.must_match(/\b1:.*unmatched/)
  end

  it "continues processing other files if one of them produces an error" do
    write_file 'a', <<-EOS.demargin
      |# frag: echo new
      |old
      |# frag end
    EOS
    write_file 'b', <<-EOS.demargin
      |# frag: false
      |old
      |# frag end
    EOS
    write_file 'c', <<-EOS.demargin
      |# frag: echo new
      |old
      |# frag end
    EOS
    frag('a', 'b', 'c').must_equal 1
    output.string.must_equal ''
    File.read('a').must_equal <<-EOS.demargin
      |# frag: echo new
      |new
      |# frag end
    EOS
    File.read('b').must_equal <<-EOS.demargin
      |# frag: false
      |old
      |# frag end
    EOS
    File.read('c').must_equal <<-EOS.demargin
      |# frag: echo new
      |new
      |# frag end
    EOS
  end

  it "prints an error if an input file does not exist" do
    frag('input').must_equal 1
    output.string.must_equal ''
    error.string.must_match /file not found.*input/
  end

  it "prints an error if an input file is not readable" do
    write_file 'input', ''
    File.chmod 0, 'input'
    frag('input').must_equal 1
    output.string.must_equal ''
    error.string.must_match /cannot open file.*input/
  end

  it "prints an error if an input file is not a file" do
    Dir.mkdir 'input'
    frag('input').must_equal 1
    output.string.must_equal ''
    error.string.must_match /not a file.*input/
  end

  it "prints an error if an input file is a dangling symlink" do
    File.symlink 'missing', 'input'
    frag('input').must_equal 1
    output.string.must_equal ''
    error.string.must_match /file not found.*input/
  end
end
