begin
  require 'rspec'
rescue LoadError
  require 'rubygems'
  require 'rspec'
end

$:.unshift(File.dirname(__FILE__) + '/../lib')
require 'hash_mapper'
