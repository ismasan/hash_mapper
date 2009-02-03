$:.unshift(File.dirname(__FILE__)) unless
  $:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))

# This allows us to call blah(&:some_method) instead of blah{|i| i.some_method }
class Symbol
  def to_proc
    Proc.new {|obj| obj.send(self) }
  end
end

module HashMapper
  VERSION = '0.0.2'
  
  def maps
    @maps ||= []
  end
  
  def map(from, to, using=nil, &filter)
    self.maps << [from, to, using]
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
  
  def normalize(incoming_hash)
    output = {}
    incoming_hash = symbolize_keys(incoming_hash)
    maps.each do |path_from, path_to, delegated_mapper|
      mapping_method = delegated_mapper.method(:normalize) if delegated_mapper
      value = path_from.extract_value_from(incoming_hash, mapping_method)
      add_value_to_hash(output, path_to, value)
    end
    output
  end

  def denormalize(norm_hash)
    output = {}
    maps.each do |path_from, path_to, delegated_mapper|
      mapping_method = delegated_mapper.method(:denormalize) if delegated_mapper
      value = path_to.extract_value_from(norm_hash, mapping_method)
      add_value_to_hash(output, path_from, value)
    end
    output
  end

  protected
  
  def add_value_to_hash(hash, path, value)
    path.inject(hash) do |h,e|
      if h[e]
        h[e]
      else
        h[e] = (e == path.last ? path.apply_filter(value) : {})
      end
    end
  end

  # from http://www.geekmade.co.uk/2008/09/ruby-tip-normalizing-hash-keys-as-symbols/
  #
  def symbolize_keys(hash)
    hash.inject({}) do |options, (key, value)|
      options[(key.to_sym rescue key) || key] = value
      options
    end
  end
  
  class PathMap
    
    include Enumerable
    
    attr_reader :segments
    
    attr_writer :filter
    
    def initialize(path)
      @path = path.dup
      @segments = parse(path)
      @filter = lambda{|value| value}# default filter does nothing
    end
    
    def apply_filter(value)
      @filter.call(value)
    end
    
    def extract_value_from(hash, mapping_method=nil)
      value = inject(hash){|hh,ee| hh[ee]}
      mapping_method ? mapping_method.call(value) : value
    end
    
    def each(&blk)
      @segments.each(&blk)
    end
    
    def last
      @segments.last
    end
    
    private
    
    def parse(path)
      path.sub(/^\//,'').split('/').map(&:to_sym)
    end
    
  end
  
end