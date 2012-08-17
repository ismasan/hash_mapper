# -*- encoding: utf-8 -*-
$:.push File.expand_path('../lib', __FILE__)
require 'hash_mapper/version'

Gem::Specification.new do |s|
  s.name        = %q{hash_mapper}
  s.version     = HashMapper::VERSION
  s.authors     = ['Ismael Celis']
  s.description = %q{Tiny module that allows you to easily adapt from one hash structure to another with a simple declarative DSL.}
  s.date        = %q{2010-09-21}
  s.email       = %q{ismaelct@gmail.com}
  
  s.files         = `git ls-files`.split("\n")
  s.homepage      = %q{http://github.com/ismasan/hash_mapper}
  s.rdoc_options  = ['--charset=UTF-8']
  s.require_paths = ['lib']
  s.summary       = %q{Maps input hashes to a normalized format}
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ['lib']
  
  if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
    s.add_runtime_dependency("activesupport", "~> 3")
  else
    s.add_dependency("activesupport", "~> 3")
  end
  
  # specify any dependencies here; for example:
  s.add_development_dependency 'rspec'
  s.add_development_dependency 'rake'
end
