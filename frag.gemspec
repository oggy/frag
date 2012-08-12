# -*- encoding: utf-8 -*-
$:.unshift File.expand_path('lib', File.dirname(__FILE__))
require 'frag/version'

Gem::Specification.new do |gem|
  gem.name          = 'frag'
  gem.version       = Frag::VERSION
  gem.authors       = ['George Ogata']
  gem.email         = ['george.ogata@gmail.com']
  gem.license       = 'MIT'
  gem.summary       = "Generate fragments of files from shell commands."
  gem.homepage      = 'http://github.com/oggy/frag'

  gem.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  gem.files         = `git ls-files`.split("\n")
  gem.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")

  gem.add_development_dependency 'ritual', '~> 0.4.1'
end
