require 'spec_helper.rb'

class OneLevel
  extend HashMapper
  map from('/name'),            to('/nombre')
end

describe 'mapping a hash with one level' do
  
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
    WithArrays.normalize(@from).should == @to
  end
  
  it "should map the other way restoring arrays" do
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

describe "with false values" do
  
  it "should include values in output" do
    NoKeys.normalize({'exists' => false}).should == {:exists_yahoo => false}
    NoKeys.normalize({:exists => false}).should == {:exists_yahoo => false}
  end
  
end

describe "with nil values" do
  
  it "should not include values in output" do
    NoKeys.normalize({:exists => nil}).should == {}
    NoKeys.normalize({'exists' => nil}).should == {}
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

class NotRelated
  extend HashMapper
  map from('/n'), to('/n/n')
end

class A
  extend HashMapper
  map from('/a'), to('/a/a')
end

class B < A
  map from('/b'), to('/b/b')
end

class C < B
  map from('/c'), to('/c/c')
end

describe "inherited mappers" do
  before :all do
    @from = {
      :a => 'a',
      :b => 'b',
      :c => 'c'
    }
    @to_b ={
      :a => {:a => 'a'},
      :b => {:b => 'b'}
    }

  end
  
  it "should inherit mappings" do
    B.normalize(@from).should == @to_b
  end
  
  it "should not affect other mappers" do
    NotRelated.normalize('n' => 'nn').should == {:n => {:n => 'nn'}}
  end
end

class MixedMappings
  extend HashMapper
  map from('/big/jobs'), to('dodo')
  map from('/timble'),   to('bingo/biscuit')
end

describe "dealing with strings and symbols" do
  
  it "should be able to normalize from a nested hash with string keys" do
    MixedMappings.normalize(
      'big' => {'jobs' => 5},
      'timble' => 3.2
    ).should ==   {:dodo  => 5,
                   :bingo => {:biscuit => 3.2}}
  end
  
  it "should not symbolized keys in value hashes" do
    MixedMappings.normalize(
      'big' => {'jobs' => 5},
      'timble' => {'string key' => 'value'}
    ).should ==   {:dodo  => 5,
                   :bingo => {:biscuit => {'string key' => 'value'}}}
  end
  
end

class DefaultValues
  extend HashMapper

  map from('/without_default'), to('not_defaulted')
  map from('/with_default'),    to('defaulted'), default: 'the_default_value'
end

describe "default values" do
  it "should use a default value whenever a key is not set" do
    DefaultValues.normalize(
      'without_default' => 'some_value'
    ).should == { not_defaulted: 'some_value', defaulted: 'the_default_value' }
  end

  it "should not use a default if a key is set (even if the value is falsy)" do
    DefaultValues.normalize({
        'without_default' => 'some_value',
        'with_default' => false
      }).should == { not_defaulted: 'some_value', defaulted: false }
  end
end

class MultiBeforeFilter
  extend HashMapper

  before_normalize do |input, output|
    input[:foo] << 'Y'
    input
  end

  before_normalize do |input, output|
    input[:foo] << 'Z'
    input
  end

  before_denormalize do |input, output|
    input[:bar].prepend('A')
    input
  end

  before_denormalize do |input, output|
    input[:bar].prepend('B')
    input
  end

  map from('/foo'), to('bar')
end

class MultiBeforeFilterSubclass < MultiBeforeFilter
  before_normalize do |input, output|
    input[:foo] << '!'
    input
  end

  before_denormalize do |input, output|
    input[:bar].prepend('C')
    input
  end
end

describe 'multiple before filters' do
  it 'runs before_normalize filters in the order they are defined' do
    MultiBeforeFilter.normalize({ foo: 'X' }).should == { bar: 'XYZ' }
  end

  it 'runs before_denormalize filters in the order they are defined' do
    MultiBeforeFilter.denormalize({ bar: 'X' }).should == { foo: 'BAX' }
  end

  context 'when the filters are spread across classes' do
    it 'runs before_normalize filters in the order they are defined' do
      MultiBeforeFilterSubclass.normalize({ foo: 'X' }).should == { bar: 'XYZ!' }
    end

    it 'runs before_denormalize filters in the order they are defined' do
      MultiBeforeFilterSubclass.denormalize({ bar: 'X' }).should == { foo: 'CBAX' }
    end
  end
end

class MultiAfterFilter
  extend HashMapper

  map from('/baz'), to('bat')

  after_normalize do |input, output|
    output[:bat] << '1'
    output
  end

  after_normalize do |input, output|
    output[:bat] << '2'
    output
  end

  after_denormalize do |input, output|
    output[:baz].prepend('9')
    output
  end

  after_denormalize do |input, output|
    output[:baz].prepend('8')
    output
  end
end

class MultiAfterFilterSubclass < MultiAfterFilter
  after_normalize do |input, output|
    output[:bat] << '3'
    output
  end

  after_denormalize do |input, output|
    output[:baz].prepend('7')
    output
  end
end

describe 'multiple after filters' do
  it 'runs after_normalize filters in the order they are defined' do
    MultiAfterFilter.normalize({ baz: '0' }).should == { bat: '012' }
  end

  it 'runs after_denormalize filters in the order they are defined' do
    MultiAfterFilter.denormalize({ bat: '0' }).should == { baz: '890' }
  end

  context 'when the filters are spread across classes' do
    it 'runs after_normalize filters in the order they are defined' do
      MultiAfterFilterSubclass.normalize({ baz: '0' }).should == { bat: '0123' }
    end

    it 'runs after_denormalize filters in the order they are defined' do
      MultiAfterFilterSubclass.denormalize({ bat: '0' }).should == { baz: '7890' }
    end
  end
end
