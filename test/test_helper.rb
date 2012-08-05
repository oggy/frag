require 'bundler'
require 'minitest/spec'
require 'debugger'

ROOT = File.expand_path('..', File.dirname(__FILE__))
$:.unshift "#{ROOT}/lib"
require 'frag'

String.class_eval do
  def demargin
    gsub(/^ *\|/, '')
  end
end

MiniTest::Spec.class_eval do
  before do
    FileUtils.mkdir_p "#{ROOT}/test/tmp"
    @original_pwd = Dir.pwd
    FileUtils.chdir "#{ROOT}/test/tmp"
  end

  after do
    FileUtils.chdir @original_pwd
    FileUtils.rm_rf "#{ROOT}/test/tmp"
  end

  def write_file(path, input)
    open(path, 'w') { |f| f.print input }
  end
end
