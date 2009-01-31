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
    OneLevel.translate(@from).should == @to
  end
  
  it "should have indifferent access" do
    OneLevel.translate({'name' => 'ismael'}).should == @to
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
    ManyLevels.translate(@from).should == @to
  end
  
end

class DifferentTypes
  extend HashMapper
  map from('/strings/a'),      to('/integers/a',:to_i)
  map from('/integers/b'),     to('/strings/b',:to_s)
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
    DifferentTypes.translate(@from).should == @to
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
    ManyLevels.translate(@from).should == @to
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
    WithArrays.translate(@from).should == @to
  end
end

class PersonWithBlock
  extend HashMapper
  
  map from('/names/first'), to('/first_name') do |name|
    "+++ #{name} +++"
  end
end

describe "with blocks filters" do
  before :each do
    @from = {
      :names => {:first => 'Ismael'}
    }
    @to = {
      :first_name => '+++ Ismael +++'
    }
  end
  
  it "should pass final value through given block" do
    PersonWithBlock.translate(@from).should == @to
  end
end

class ProjectMapper
  extend HashMapper
  
  map from('/name'),        to('/project_name')
  map from('/author_hash'), to('/author'), &PersonWithBlock
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
      :author => {:first_name => '+++ Ismael +++'}
    }
  end
  
  it "should delegate nested hashes to another mapper" do
    ProjectMapper.translate(@from).should == @to
  end
end

class CompanyMapper
  extend HashMapper
  
  map from('/name'),      to('/company_name')
  map from('/employees'), to('/employees') do |employees_array|
    employees_array.collect{|emp_hash| PersonWithBlock.translate(emp_hash)}
  end
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
        {:first_name => '+++ Ismael +++'},
        {:first_name => '+++ Sachiyo +++'},
        {:first_name => '+++ Pedro +++'}
      ]
    }
  end
  
  it "should pass array value though given block mapper" do
    CompanyMapper.translate(@from).should == @to
  end
end


