# frozen_string_literal: true

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
unless :symbol.respond_to?(:to_proc)
  class Symbol
    def to_proc
      Proc.new {|obj| obj.send(self) }
    end
  end
end

# http://rpheath.com/posts/341-ruby-inject-with-index
unless [].respond_to?(:inject_with_index)
  module Enumerable
    def inject_with_index(injected)
      each_with_index{ |obj, index| injected = yield(injected, obj, index) }
      injected
    end
  end
end

module HashMapper
  DEFAULT_OPTIONS = {}.freeze
  NO_VALUE = :hash_mapper_no_value
  NO_DEFAULT = :hash_mapper_no_default

  def self.extended(base)
    base.class_eval do
      class_attribute :maps, :before_normalize_filters,
        :before_denormalize_filters, :after_normalize_filters,
        :after_denormalize_filters

      self.maps = []
      self.before_normalize_filters = []
      self.before_denormalize_filters = []
      self.after_normalize_filters = []
      self.after_denormalize_filters = []
    end
  end

  def map(from, to, options={}, &block_filter)
    filter = options.delete(:filter) || block_filter
    self.maps = self.maps.dup
    self.maps << Map.new(from, to, options)
    to.filter = filter if filter # Useful if just one block given
  end

  def from(path, filter: nil, &block_filter)
    path_map = PathMap.new(path)
    filter ||= block_filter if block_given?
    path_map.filter = filter if filter # Useful if two blocks given
    path_map
  end

  def import_mapper(mapper)
    self.maps = self.maps + mapper.maps.dup
  end

  alias :to :from

  def using(mapper_class)
    warn "[DEPRECATION] `using` is deprecated, instead of `using(#{mapper_class.name})` you should specify `{ using: #{mapper_class.name} }`"
    { using: mapper_class }
  end

  def normalize(a_hash, options: DEFAULT_OPTIONS, context: nil)
    perform_hash_mapping a_hash, :normalize, options: options, context: context
  end

  def denormalize(a_hash, options: DEFAULT_OPTIONS, context: nil)
    perform_hash_mapping a_hash, :denormalize, options: options, context: context
  end

  def before_normalize(&blk)
    self.before_normalize_filters = self.before_normalize_filters + [blk]
  end

  def before_denormalize(&blk)
    self.before_denormalize_filters = self.before_denormalize_filters + [blk]
  end

  def after_normalize(&blk)
    self.after_normalize_filters = self.after_normalize_filters + [blk]
  end

  def after_denormalize(&blk)
    self.after_denormalize_filters = self.after_denormalize_filters + [blk]
  end

  protected

  def perform_hash_mapping(a_hash, meth, options:, context:)
    output = {}

    # Before filters
    a_hash = self.send(:"before_#{meth}_filters").inject(a_hash) do |memo, filter|
      filter.call(memo, output, options)
    end

    # Do the mapping
    self.maps.each do |m|
      m.process_into(output, a_hash, method_name: meth, context: context)
    end

    # After filters
    self.send(:"after_#{meth}_filters").inject(output) do |memo, filter|
      filter.call(a_hash, memo, options)
    end
  end

  # Contains PathMaps
  # Makes them interact
  #
  class Map

    attr_reader :path_from, :path_to, :delegated_mapper, :default_value

    def initialize(path_from, path_to, options = {})
      @path_from = path_from
      @path_to = path_to
      @delegated_mapper = options.fetch(:using, nil)
      @default_value = options.fetch(:default, NO_DEFAULT)
    end

    def process_into(output, input, method_name: :normalize, context: nil)
      path_1, path_2 = (method_name == :normalize ? [path_from, path_to] : [path_to, path_from])
      value = get_value_from_input(output, input, path_1, method_name: method_name, context: context)
      set_value_in_output(output, path_2, value, context: context)
    end
    protected

    def get_value_from_input(output, input, path, method_name:, context:)
      value = path.inject(input) do |h,e|
        if h.is_a?(Hash)
          v = [h[e.to_sym], h[e.to_s]].compact.first
        else
          v = h[e]
        end
        return NO_VALUE if v.nil?
        v
      end
      delegated_mapper ? delegate_to_nested_mapper(value, method_name, context: context) : value
    end

    def set_value_in_output(output, path, value, context: nil)
      if value == NO_VALUE
        if default_value == NO_DEFAULT
          return
        else
          value = default_value
        end
      end
      add_value_to_hash!(output, path, value, context: context)
    end

    def delegate_to_nested_mapper(value, method_name, context:)
      case value
      when Array
        value.map {|v| delegated_mapper.public_send(method_name, v, context: context)}
      when nil
        return NO_VALUE
      else
        delegated_mapper.public_send(method_name, value, context: context)
      end
    end

    def add_value_to_hash!(hash, path, value, context: nil)
      path.inject_with_index(hash) do |h,e,i|
        if !h[e].nil? # it can be FALSE
          h[e]
        else
          h[e] = if i == path.size-1
            path.apply_filter(value, context: context)
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
    attr_reader :path

    def initialize(path)
      @path = path.dup
      @segments = parse(path)
      @filter = lambda{|value| value}# default filter does nothing
      @filter_arity = 1
    end

    def filter=(f)
      @filter_arity = f.respond_to?(:arity) ? f.arity : 1
      @filter = f
    end

    def apply_filter(value, context: nil)
      args = [value]
      args << context if @filter_arity > 1
      @filter.call(*args)
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
