require_relative 'test_helper'
require 'open3'

describe Frag do
  def frag(*args)
    ruby = RbConfig::CONFIG.values_at('bindir', 'ruby_install_name').join('/')
    command = [ruby, '-I', "#{ROOT}/lib", "#{ROOT}/bin/frag", *args]
    @output, @error, status = Open3.capture3(*command)
    status
  end

  describe "when a file is frag'd successfully" do
    it "updates the file, and exits with zero status" do
      write_file 'input', <<-EOS.demargin
        |# frag: echo new
        |old
        |# frag end
      EOS
      frag('input').must_equal 0
      File.read('input').must_equal <<-EOS.demargin
        |# frag: echo new
        |new
        |# frag end
      EOS
    end
  end

  describe "when options are used succesfully" do
    it "updates the file, and exits with zero status" do
      write_file 'input', <<-EOS.demargin
        |# frag: echo new
        |old
        |# frag end
        |// frag: echo new
        |old
        |// frag end
      EOS
      frag('-l', '//', 'input').must_equal 0
      File.read('input').must_equal <<-EOS.demargin
        |# frag: echo new
        |old
        |# frag end
        |// frag: echo new
        |new
        |// frag end
      EOS
    end
  end
end
