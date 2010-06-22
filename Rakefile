require 'rubygems'
require File.dirname(__FILE__) + '/lib/hash_mapper'

Dir['tasks/**/*.rake'].each { |t| load t }

# TODO - want other tests/tasks run by default? Add them to the list
task :default => [:spec]


begin
  require 'jeweler'
  Jeweler::Tasks.new do |gemspec|
    gemspec.name = "hash_mapper"
    gemspec.summary = "Maps values from hashes with different structures and/or key names. Ideal for normalizing arbitrary data to be consumed by your applications, or to prepare your data for different display formats (ie. json)"
    gemspec.description = "Tiny module that allows you to easily adapt from one hash structure to another with a simple declarative DSL."
    gemspec.email = "ismaelct@gmail.com"
    gemspec.homepage = "http://github.com/ismasan/hash_mapper"
    gemspec.add_dependency('active_support', '>= 3.0.0.beta')
    gemspec.authors = ["Ismael Celis"]
  end
rescue LoadError
  puts "Jeweler not available. Install it with: sudo gem install technicalpickles-jeweler -s http://gems.github.com"
end
