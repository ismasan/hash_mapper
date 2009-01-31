$:.unshift(File.dirname(__FILE__)) unless
  $:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))

module HashMapper
  VERSION = '0.0.1'
  
  def maps
    @maps ||= []
  end
  
  def map(from, to)
    self.maps << [from, to]
  end
  
  def from(path)
    PathMap.new(path)
  end
  
  alias :to :from
  
  def translate(incoming_hash)
    output = {}
    incoming_hash = simbolize_keys(incoming_hash)
    maps.each do |path_from, path_to|
        path_to.inject(output){|h,e|
          if h[e]
            h[e]
          else
            puts e.inspect
            h[e] = (e == path_to.last ? path_from.inject(incoming_hash){|hh,ee| hh[ee]} : {})
          end
        }
    end
    output
  end
  
  # from http://www.geekmade.co.uk/2008/09/ruby-tip-normalizing-hash-keys-as-symbols/
  #
  def simbolize_keys(hash)
    hash.inject({}) do |options, (key, value)|
      options[(key.to_sym rescue key) || key] = value
      options
    end
  end
  
  class PathMap
    
    include Enumerable
    
    attr_reader :segments
    
    def initialize(path)
      @path = path
      @segments = parse(path)
    end
    
    def to_s
      @path
    end
    
    def each(&blk)
      @segments.each(&blk)
    end
    
    def last
      @segments.last
    end
    
    private
    
    def parse(path)
      path = path.split('/')
      path.shift
      path.collect{|e| e.to_sym}
    end
    
  end
  
end