require 'hash_mapper/version'

$:.unshift(File.dirname(__FILE__)) unless
$:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))

def require_active_support
  require 'active_support/core_ext/array/extract_options'
  require 'active_support/core_ext/hash/indifferent_access'
  require 'active_support/core_ext/object/duplicable'
  require 'active_support/core_ext/class/attribute'
end

begin
  require_active_support
rescue LoadError
  require 'rubygems'
  require_active_support
end



# This allows us to call blah(&:some_method) instead of blah{|i| i.some_method }
unless Symbol.instance_methods.include?('to_proc')
  class Symbol
    def to_proc
      Proc.new {|obj| obj.send(self) }
    end
  end
end

# http://rpheath.com/posts/341-ruby-inject-with-index
unless Array.instance_methods.include?("inject_with_index")
  module Enumerable
    def inject_with_index(injected)
      each_with_index{ |obj, index| injected = yield(injected, obj, index) }
      injected
    end
  end
end

module HashMapper

  def self.extended(base)
    base.class_eval do
      class_attribute :maps
      self.maps = []
    end
  end

  def map(from, to, using=nil, &filter)
    self.maps = self.maps.dup
    self.maps << Map.new(from, to, using)
    to.filter = filter if block_given? # Useful if just one block given
  end

  def from(path, &filter)
    path_map = PathMap.new(path)
    path_map.filter = filter if block_given? # Useful if two blocks given
    path_map
  end

  alias :to :from

  def using(mapper_class)
    mapper_class
  end

  def normalize(a_hash)
    perform_hash_mapping a_hash, :normalize
  end

  def denormalize(a_hash)
    perform_hash_mapping a_hash, :denormalize
  end

  def before_normalize(&blk)
    @before_normalize = blk
  end

  def before_denormalize(&blk)
    @before_denormalize = blk
  end

  def after_normalize(&blk)
    @after_normalize = blk
  end

  def after_denormalize(&blk)
    @after_denormalize = blk
  end

  protected


  def perform_hash_mapping(a_hash, meth)
    output = {}
    # Before filter
    before_filter = instance_eval "@before_#{meth}"
    a_hash = before_filter.call(a_hash, output) if before_filter
    # Do the mapping
    self.maps.each do |m|
      m.process_into(output, a_hash, meth)
    end
    # After filter
    after_filter = instance_eval "@after_#{meth}"
    output = after_filter.call(a_hash, output) if after_filter
    # Return
    output
  end

  # Contains PathMaps
  # Makes them interact
  #
  class Map

    attr_reader :path_from, :path_to, :delegated_mapper

    def initialize(path_from, path_to, delegated_mapper = nil)
      @path_from, @path_to, @delegated_mapper = path_from, path_to, delegated_mapper
    end

    def process_into(output, input, meth = :normalize)
      path_1, path_2 = (meth == :normalize ? [path_from, path_to] : [path_to, path_from])
      value = get_value_from_input(output, input, path_1, meth)
      add_value_to_hash!(output, path_2, value) unless value == :hash_mapper_no_value
    end
    protected

    def get_value_from_input(output, input, path, meth)
      value = path.inject(input) do |h,e|
        if h.is_a?(Hash)
          v = [h[e.to_sym], h[e.to_s]].compact.first
        else
          v = h[e]
        end
        return :hash_mapper_no_value if v.nil?
        v
      end
      delegated_mapper ? delegate_to_nested_mapper(value, meth) : value
    end


    def delegate_to_nested_mapper(value, meth)
      case value
      when Array
        value.map {|h| delegated_mapper.send(meth, h)}
      when nil
        return :hash_mapper_no_value
      else
        delegated_mapper.send(meth, value)
      end
    end

    def add_value_to_hash!(hash, path, value)
      path.inject_with_index(hash) do |h,e,i|
        if !h[e].nil? # it can be FALSE
          h[e]
        else
          h[e] = if i == path.size-1
            path.apply_filter(value)
          else
            if path.segments[i+1].is_a? Integer
              []
            else
              {}
            end
          end
        end
      end

    end

  end

  # contains array of path segments
  #
  class PathMap
    include Enumerable

    attr_reader :segments
    attr_writer :filter
    attr_reader :path

    def initialize(path)
      @path = path.dup
      @segments = parse(path)
      @filter = lambda{|value| value}# default filter does nothing
    end

    def apply_filter(value)
      @filter.call(value)
    end

    def each(&blk)
      @segments.each(&blk)
    end

    def first
      @segments.first
    end

    def last
      @segments.last
    end

    def size
      @segments.size
    end

    private
    KEY_NAME_REGEXP = /([^\[]*)(\[(\d+)+\])?/

    def parse(path)
      segments = path.sub(/^\//,'').split('/')
      segments = segments.collect do |segment|
        matches = segment.to_s.scan(KEY_NAME_REGEXP).flatten.compact
        index = matches[2]
        if index
          [matches[0].to_sym, index.to_i]
        else
          segment.to_sym
        end
      end.flatten
      segments
    end

  end

end
