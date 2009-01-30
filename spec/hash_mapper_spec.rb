require File.dirname(__FILE__) + '/spec_helper.rb'

class OneLevel
  extend HashMapper
  map from('/name'),            to('/nombre')
end

class ManyLevels
  extend HashMapper
  map from('/name'),            to('/tag_attributes/name')
  map from('/properties/type'), to('/tag_attributes/type')
  map from('/tagid'),           to('/tag_id')
  map from('/properties/egg'),  to('/chicken')
end


describe OneLevel do
  
  describe 'mapping a hash' do
    
    before :each do
      @from = {:name => 'ismael'}
      @to   = {:nombre => 'ismael'}
    end
    
    it "should map to" do
      OneLevel.translate(@from).should == @to
    end
    
  end
  
end

describe ManyLevels do
  
  describe 'mapping a hash' do
    
    before :each do
      @from = {
        :name => 'ismael',
        :tagid => 1,
        :properties => {
          :type => 'BLAH',
          :egg => 33
        }
      }
      
      @to   = {
        :tag_id => 1,
        :chicken => 33,
        :tag_attributes => {
          :name => 'ismael',
          :type => 'BLAH'
        }
      }
    end
    
    it "should map to" do
      ManyLevels.translate(@from).should == @to
    end
    
  end
  
end

describe "hashes" do
  before :all do
    @input = {:a => {:b => {:c => 666}}}
    @m = [:a, :b, :c]
    @l = lambda {|h,e|
      h[e]
    }
  end
  
  it "should get to the end" do
    @m.inject(@input, &@l).should === 666
  end
  
  it "should return nil if not in hash" do
    [:a, :b, :c, :d].inject(@input, &@l).should === nil
  end
  
  it "should build tree" do
    output = {}
    
    incoming  = {:z => {:fox => 44}}
    map_from  = [:z,:fox]
    map_to    = [:a, :b, :c, :d]
    
    map_to.inject(output){|h,e|h[e] = (e == map_to.last ? map_from.inject(incoming){|h,e| h[e]} : {})}
    output.should == {:a => {:b => {:c => {:d => 44}}}}
  end
end
