require_relative '../test_helper'
require 'stringio'
require 'tempfile'

describe Frag::App do
  def write_file(path, input)
    open(path, 'w') { |f| f.print input }
  end

  let(:input) { StringIO.new }
  let(:output) { StringIO.new }
  let(:error) { StringIO.new }

  def frag(*args)
    Frag::App.new(args, input, output, error).run
  end

  describe "when no options are used" do
    it "populates the delimited region if it's empty" do
      write_file 'input', <<-EOS.demargin
        |# GEN: echo hi
        |# ENDGEN
      EOS
      frag('input').must_equal 0
      (output.string + error.string).must_equal ''
      File.read('input').must_equal <<-EOS.demargin
        |# GEN: echo hi
        |hi
        |# ENDGEN
      EOS
    end

    it "replaces the delimited region if there's already something there" do
      write_file 'input', <<-EOS.demargin
        |# GEN: echo new
        |old
        |# ENDGEN
      EOS
      frag('input').must_equal 0
      (output.string + error.string).must_equal ''
      File.read('input').must_equal <<-EOS.demargin
        |# GEN: echo new
        |new
        |# ENDGEN
      EOS
    end

    it "appends a newline if the command output doesn't end in one" do
      write_file 'input', <<-EOS.demargin
        |# GEN: echo -n hi
        |# ENDGEN
      EOS
      frag('input').must_equal 0
      (output.string + error.string).must_equal ''
      File.read('input').must_equal <<-EOS.demargin
        |# GEN: echo -n hi
        |hi
        |# ENDGEN
      EOS
    end

    it "processes multiple regions, and leave surrounding content alone" do
      write_file 'input', <<-EOS.demargin
        |before
        |# GEN: echo one
        |# ENDGEN
        |middle
        |# GEN: echo two
        |# ENDGEN
        |after
      EOS
      frag('input').must_equal 0
      (output.string + error.string).must_equal ''
      File.read('input').must_equal <<-EOS.demargin
        |before
        |# GEN: echo one
        |one
        |# ENDGEN
        |middle
        |# GEN: echo two
        |two
        |# ENDGEN
        |after
      EOS
    end

    it "can process multiple files" do
      write_file 'one', <<-EOS.demargin
        |# GEN: echo one
        |# ENDGEN
      EOS
      write_file 'two', <<-EOS.demargin
        |# GEN: echo two
        |# ENDGEN
      EOS
      frag('one', 'two').must_equal 0
      (output.string + error.string).must_equal ''
      File.read('one').must_equal <<-EOS.demargin
        |# GEN: echo one
        |one
        |# ENDGEN
      EOS
      File.read('two').must_equal <<-EOS.demargin
        |# GEN: echo two
        |two
        |# ENDGEN
      EOS
    end
  end

  describe "when the delimiter options are used" do
    ['-b', '--begin'].each do |option|
      it "uses the beginning delimiter given by #{option}" do
        write_file 'input', <<-EOS.demargin
          |# BEGIN echo one
          |# ENDGEN
        EOS
        frag(option, 'BEGIN', 'input').must_equal 0
        (output.string + error.string).must_equal ''
        File.read('input').must_equal <<-EOS.demargin
          |# BEGIN echo one
          |one
          |# ENDGEN
        EOS
      end
    end

    ['-e', '--end'].each do |option|
      it "uses the ending delimiter given by #{option}" do
        write_file 'input', <<-EOS.demargin
          |# GEN: echo one
          |# END
        EOS
        frag(option, 'END', 'input').must_equal 0
        (output.string + error.string).must_equal ''
        File.read('input').must_equal <<-EOS.demargin
          |# GEN: echo one
          |one
          |# END
        EOS
      end
    end

    ['-l', '--leader'].each do |option|
      it "uses the delimiter leader given by #{option}" do
        write_file 'input', <<-EOS.demargin
          |// GEN: echo one
          |// ENDGEN
        EOS
        frag(option, '//', 'input').must_equal 0
        (output.string + error.string).must_equal ''
        File.read('input').must_equal <<-EOS.demargin
          |// GEN: echo one
          |one
          |// ENDGEN
        EOS
      end
    end

    ['-t', '--trailer'].each do |option|
      it "uses the delimiter trailer given by #{option}" do
        write_file 'input', <<-EOS.demargin
          |# GEN: echo one !!
          |# ENDGEN !!
        EOS
        frag(option, '!!', 'input').must_equal 0
        (output.string + error.string).must_equal ''
        File.read('input').must_equal <<-EOS.demargin
          |# GEN: echo one !!
          |one
          |# ENDGEN !!
        EOS
      end
    end

    it "supports using delimiter options together" do
      write_file 'input', <<-EOS.demargin
        |<!-- BEGIN echo one -->
        |<!-- END -->
      EOS
      frag('-b', 'BEGIN', '-e', 'END', '-l', '<!--', '-t', '-->', 'input').must_equal 0
      (output.string + error.string).must_equal ''
      File.read('input').must_equal <<-EOS.demargin
        |<!-- BEGIN echo one -->
        |one
        |<!-- END -->
      EOS
    end
  end

  it "prints an error and leaves the input file unchanged if a command fails" do
    write_file 'input', <<-EOS.demargin
      |# GEN: echo new
      |old
      |# ENDGEN
      |# GEN: false
      |# ENDGEN
    EOS
    frag('input').must_equal 1
    output.string.must_equal ''
    error.string.must_match(/\b4:.*failed/)
    File.read('input').must_equal <<-EOS.demargin
      |# GEN: echo new
      |old
      |# ENDGEN
      |# GEN: false
      |# ENDGEN
    EOS
  end

  it "prints an error if there's an unmatched beginning line" do
    write_file 'input', <<-EOS.demargin
      |# GEN: echo one
    EOS
    frag('input').must_equal 1
    output.string.must_equal ''
    error.string.must_match(/\b1:.*unmatched/)
  end

  it "prints an error if there's an unmatched ending line" do
    write_file 'input', <<-EOS.demargin
      |# ENDGEN
    EOS
    frag('input').must_equal 1
    output.string.must_equal ''
    error.string.must_match(/\b1:.*unmatched/)
  end
end
