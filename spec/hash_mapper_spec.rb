require File.dirname(__FILE__) + '/spec_helper.rb'

class OneLevel
  extend HashMapper
  map from('/name'),            to('/nombre')
end

describe 'mapping a hash wit one level' do
  
  before :each do
    @from = {:name => 'ismael'}
    @to   = {:nombre => 'ismael'}
  end
  
  it "should map to" do
    OneLevel.normalize(@from).should == @to
  end
  
  it "should have indifferent access" do
    OneLevel.normalize({'name' => 'ismael'}).should == @to
  end
  
  it "should map back the other way" do
    OneLevel.denormalize(@to).should == @from
  end
  
end

class ManyLevels
  extend HashMapper
  map from('/name'),            to('/tag_attributes/name')
  map from('/properties/type'), to('/tag_attributes/type')
  map from('/tagid'),           to('/tag_id')
  map from('/properties/egg'),  to('/chicken')
end

describe 'mapping from one nested hash to another' do
  
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
  
  it "should map from and to different depths" do
    ManyLevels.normalize(@from).should == @to
  end
  
  it "should map back the other way" do
    ManyLevels.denormalize(@to).should == @from
  end
  
end

class DifferentTypes
  extend HashMapper
  map from('/strings/a',  &:to_s),      to('/integers/a', &:to_i)
  map from('/integers/b', &:to_i),     to('/strings/b',   &:to_s)
end

describe 'coercing types' do
  
  before :each do
    @from = {
      :strings => {:a => '10'},
      :integers =>{:b => 20}
    }
    
    @to   = {
      :integers => {:a => 10},
      :strings  => {:b => '20'}
    }
  end
  
  it "should coerce values to specified types" do
    DifferentTypes.normalize(@from).should == @to
  end
  
  it "should coerce the other way if specified" do
    DifferentTypes.denormalize(@to).should == @from
  end
  
end


describe 'arrays in hashes' do
  before :each do
    @from = {
      :name => ['ismael','sachiyo'],
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
        :name => ['ismael','sachiyo'],
        :type => 'BLAH'
      }
    }
  end
  
  it "should map array values as normal" do
    ManyLevels.normalize(@from).should == @to
  end
end

class WithArrays
  extend HashMapper
  map from('/arrays/names[0]'),      to('/first_name')
  map from('/arrays/names[1]'),      to('/last_name')
  map from('/arrays/company'),       to('/work/company')
end
 
describe "array indexes" do
  before :each do
    @from = {
      :arrays => {
        :names => ['ismael','celis'],
        :company => 'New Bamboo'
      }
    }
    @to ={
      :first_name => 'ismael',
      :last_name => 'celis',
      :work       => {:company => 'New Bamboo'}
    }
  end
  
  it "should extract defined array values" do
    pending
    WithArrays.normalize(@from).should == @to
  end
  
  it "should map the other way restoring arrays" do
    pending
    WithArrays.denormalize(@to).should == @from
  end
end

class PersonWithBlock
  extend HashMapper
  def self.normalize(h)
    super
  end
  map from('/names/first'){|n| n.gsub('+','')}, to('/first_name'){|n| "+++#{n}+++"}
end
class PersonWithBlockOneWay
  extend HashMapper
  map from('/names/first'), to('/first_name') do |n| "+++#{n}+++" end
end

describe "with blocks filters" do
  before :each do
    @from = {
      :names => {:first => 'Ismael'}
    }
    @to = {
      :first_name => '+++Ismael+++'
    }
  end
  
  it "should pass final value through given block" do
    PersonWithBlock.normalize(@from).should == @to
  end
  
  it "should be able to map the other way using a block" do
    PersonWithBlock.denormalize(@to).should == @from
  end
  
  it "should accept a block for just one direction" do
    PersonWithBlockOneWay.normalize(@from).should == @to
  end
  
end

class ProjectMapper
  extend HashMapper
  
  map from('/name'),        to('/project_name')
  map from('/author_hash'), to('/author'), using(PersonWithBlock)
end

describe "with nested mapper" do
  before :each do
    @from ={
      :name => 'HashMapper',
      :author_hash => {
        :names => {:first => 'Ismael'}
      }
    }
    @to = {
      :project_name => 'HashMapper',
      :author => {:first_name => '+++Ismael+++'}
    }
  end
  
  it "should delegate nested hashes to another mapper" do
    ProjectMapper.normalize(@from).should == @to
  end
  
  it "should translate the other way using nested hashes" do
    ProjectMapper.denormalize(@to).should == @from
  end
  
end

class CompanyMapper
  extend HashMapper
  
  map from('/name'),      to('/company_name')
  map from('/employees'), to('/employees') do |employees_array|
    employees_array.collect{|emp_hash| PersonWithBlock.normalize(emp_hash)}
  end
end

class CompanyEmployeesMapper
  extend HashMapper
  
  map from('/name'),      to('/company_name')
  map from('/employees'), to('/employees'), using(PersonWithBlock)
end

describe "with arrays of nested hashes" do
  before :each do
    @from = {
      :name => 'New Bamboo',
      :employees => [
        {:names => {:first => 'Ismael'}},
        {:names => {:first => 'Sachiyo'}},
        {:names => {:first => 'Pedro'}}
      ]
    }
    @to = {
      :company_name => 'New Bamboo',
      :employees => [
        {:first_name => '+++Ismael+++'},
        {:first_name => '+++Sachiyo+++'},
        {:first_name => '+++Pedro+++'}
      ]
    }
  end
  
  it "should pass array value though given block mapper" do
    CompanyMapper.normalize(@from).should == @to
  end
  
  it "should map array elements automatically" do
    CompanyEmployeesMapper.normalize(@from).should == @to
  end
end

class NoKeys
  extend HashMapper
  
  map from('/exists'), to('/exists_yahoo') #in
  map from('/exists_as_nil'), to('/exists_nil') #in
  map from('/foo'), to('/bar') # not in
  
end

describe "with non-matching maps" do
  before :all do
    @input = {
      :exists => 1,
      :exists_as_nil => nil,
      :doesnt_exist => 2
    }
    @output = {
      :exists_yahoo => 1
    }
  end
  
  it "should ignore maps that don't exist" do
    NoKeys.normalize(@input).should == @output
  end
end

class WithBeforeFilters
  extend HashMapper
  map from('/hello'), to('/goodbye')
  map from('/extra'), to('/extra')

  before_normalize do |input, output|
    input[:extra] = "extra #{input[:hello]} innit"
    input
  end
  before_denormalize do |input, output|
    input[:goodbye] = 'changed'
    input
  end
end

class WithAfterFilters
  extend HashMapper
  map from('/hello'), to('/goodbye')

  after_normalize do |input, output|
    output = output.to_a
    output
  end
  after_denormalize do |input, output|
    output.delete(:hello)
    output
  end
end

describe "before and after filters" do
  before(:all) do
    @denorm = {:hello   => 'wassup?!'}
    @norm   = {:goodbye => 'seeya later!'}
  end
  it "should allow filtering before normalize" do
    WithBeforeFilters.normalize(@denorm).should == {:goodbye => 'wassup?!', :extra => 'extra wassup?! innit'}
  end
  it "should allow filtering before denormalize" do
    WithBeforeFilters.denormalize(@norm).should == {:hello => 'changed'}
  end
  it "should allow filtering after normalize" do
    WithAfterFilters.normalize(@denorm).should == [[:goodbye, 'wassup?!']]
  end
  it "should allow filtering after denormalize" do
    WithAfterFilters.denormalize(@norm).should == {}
  end

end

class C
  extend HashMapper
  map from('/c'), to('/c/c2')
end

class A
  extend HashMapper
  map from('/a'), to('/a/a2')
end

class B < A
  map from('/b'), to('/b/b2')
end

describe "inherited mappers" do
  before :all do
    @from = {
      :a => 'a',
      :b => 'b'
    }
    @to ={
      :a => {:a2 => 'a'},
      :b => {:b2 => 'b'}
    }

  end
  
  it "should inherit mappings" do
    B.normalize(@from).should == @to
  end
  
  it "should not affect other mappers" do
    C.normalize('c' => 'cc').should == {:c => {:c2 => 'cc'}}
  end
end