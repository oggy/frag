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

  it "exits with an error, and leaves the input file unchanged if there's an unmatched beginning line" do
    write_file 'input', <<-EOS.demargin
      |# GEN: echo one
      |old
      |# ENDGEN
      |# GEN: echo two
    EOS
    frag('input').must_equal 1
    output.string.must_equal ''
    error.string.must_match(/\b4:.*unmatched/)
    File.read('input').must_equal <<-EOS.demargin
      |# GEN: echo one
      |old
      |# ENDGEN
      |# GEN: echo two
    EOS
  end
end
