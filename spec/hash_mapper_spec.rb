class OneLevel
  extend HashMapper
  map from('/name'),            to('/nombre')
end

describe 'mapping a hash with one level' do

  before :each do
    @from = {name: 'ismael'}
    @to   = {nombre: 'ismael'}
  end

  it "should map to" do
    expect(OneLevel.normalize(@from)).to eq(@to)
  end

  it "should have indifferent access" do
    expect(OneLevel.normalize({'name' => 'ismael'})).to eq(@to)
  end

  it "should map back the other way" do
    expect(OneLevel.denormalize(@to)).to eq(@from)
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
      name: 'ismael',
      tagid: 1,
      properties: {
        type: 'BLAH',
        egg: 33
      }
    }

    @to   = {
      tag_id: 1,
      chicken: 33,
      tag_attributes: {
        name: 'ismael',
        type: 'BLAH'
      }
    }
  end

  it "should map from and to different depths" do
    expect(ManyLevels.normalize(@from)).to eq(@to)
  end

  it "should map back the other way" do
    expect(ManyLevels.denormalize(@to)).to eq(@from)
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
      strings: {a: '10'},
      integers: {b: 20}
    }

    @to   = {
      integers: {a: 10},
      strings: {b: '20'}
    }
  end

  it "should coerce values to specified types" do
    expect(DifferentTypes.normalize(@from)).to eq(@to)
  end

  it "should coerce the other way if specified" do
    expect(DifferentTypes.denormalize(@to)).to eq(@from)
  end

end


describe 'arrays in hashes' do
  before :each do
    @from = {
      name: ['ismael','sachiyo'],
      tagid: 1,
      properties: {
        type: 'BLAH',
        egg: 33
      }
    }

    @to   = {
      tag_id: 1,
      chicken: 33,
      tag_attributes: {
        name: ['ismael','sachiyo'],
        type: 'BLAH'
      }
    }
  end

  it "should map array values as normal" do
    expect(ManyLevels.normalize(@from)).to eq(@to)
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
      arrays: {
        names: ['ismael','celis'],
        company: 'New Bamboo'
      }
    }
    @to = {
      first_name: 'ismael',
      last_name: 'celis',
      work: {company: 'New Bamboo'}
    }
  end

  it "should extract defined array values" do
    expect(WithArrays.normalize(@from)).to eq(@to)
  end

  it "should map the other way restoring arrays" do
    expect(WithArrays.denormalize(@to)).to eq(@from)
  end
end

class PersonWithBlock
  extend HashMapper
  def self.normalize(*_)
    super
  end
  map from('/names/first'){|n| n.gsub('+','')}, to('/first_name'){|n| "+++#{n}+++"}
end
class PersonWithBlockOneWay
  extend HashMapper
  map from('/names/first'), to('/first_name') do |n| "+++#{n}+++" end
end

describe "with block filters" do
  before :each do
    @from = {
      names: {first: 'Ismael'}
    }
    @to = {
      first_name: '+++Ismael+++'
    }
  end

  it "should pass final value through given block" do
    expect(PersonWithBlock.normalize(@from)).to eq(@to)
  end

  it "should be able to map the other way using a block" do
    expect(PersonWithBlock.denormalize(@to)).to eq(@from)
  end

  it "should accept a block for just one direction" do
    expect(PersonWithBlockOneWay.normalize(@from)).to eq(@to)
  end

end

class ProjectMapper
  extend HashMapper

  map from('/name'),        to('/project_name')
  map from('/author_hash'), to('/author'), using: PersonWithBlock
end

describe "with nested mapper" do
  before :each do
    @from ={
      name: 'HashMapper',
      author_hash: {
        names: {first: 'Ismael'}
      }
    }
    @to = {
      project_name: 'HashMapper',
      author: {first_name: '+++Ismael+++'}
    }
  end

  it "should delegate nested hashes to another mapper" do
    expect(ProjectMapper.normalize(@from)).to eq(@to)
  end

  it "should translate the other way using nested hashes" do
    expect(ProjectMapper.denormalize(@to)).to eq(@from)
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
  map from('/employees'), to('/employees'), using: PersonWithBlock
end

describe "with arrays of nested hashes" do
  before :each do
    @from = {
      name: 'New Bamboo',
      employees: [
        {names: {first: 'Ismael'}},
        {names: {first: 'Sachiyo'}},
        {names: {first: 'Pedro'}}
      ]
    }
    @to = {
      company_name: 'New Bamboo',
      employees: [
        {first_name: '+++Ismael+++'},
        {first_name: '+++Sachiyo+++'},
        {first_name: '+++Pedro+++'}
      ]
    }
  end

  it "should pass array value though given block mapper" do
    expect(CompanyMapper.normalize(@from)).to eq(@to)
  end

  it "should map array elements automatically" do
    expect(CompanyEmployeesMapper.normalize(@from)).to eq(@to)
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
      exists: 1,
      exists_as_nil: nil,
      doesnt_exist: 2
    }
    @output = {
      exists_yahoo: 1
    }
  end

  it "should ignore maps that don't exist" do
    expect(NoKeys.normalize(@input)).to eq(@output)
  end
end

describe "with false values" do

  it "should include values in output" do
    expect(NoKeys.normalize({'exists' => false})).to eq({exists_yahoo: false})
    expect(NoKeys.normalize({exists: false})).to eq({exists_yahoo: false})
  end

end

describe "with nil values" do

  it "should not include values in output" do
    expect(NoKeys.normalize({exists: nil})).to eq({})
    expect(NoKeys.normalize({'exists' => nil})).to eq({})
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
    @denorm = {hello: 'wassup?!'}
    @norm   = {goodbye: 'seeya later!'}
  end

  it "should allow filtering before normalize" do
    expect(WithBeforeFilters.normalize(@denorm)).to eq({goodbye: 'wassup?!', extra: 'extra wassup?! innit'})
  end
  it "should allow filtering before denormalize" do
    expect(WithBeforeFilters.denormalize(@norm)).to eq({hello: 'changed'})
  end
  it "should allow filtering after normalize" do
    expect(WithAfterFilters.normalize(@denorm)).to eq([[:goodbye, 'wassup?!']])
  end
  it "should allow filtering after denormalize" do
    expect(WithAfterFilters.denormalize(@norm)).to eq({})
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
      a: 'a',
      b: 'b',
      c: 'c'
    }
    @to_b ={
      a: {a: 'a'},
      b: {b: 'b'}
    }

  end

  it "should inherit mappings" do
    expect(B.normalize(@from)).to eq(@to_b)
  end

  it "should not affect other mappers" do
    expect(NotRelated.normalize({ 'n' => 'nn' })).to eq({n: {n: 'nn'}})
  end
end

class MixedMappings
  extend HashMapper
  map from('/big/jobs'), to('dodo')
  map from('/timble'),   to('bingo/biscuit')
end

describe "dealing with strings and symbols" do

  it "should be able to normalize from a nested hash with string keys" do
    expect(MixedMappings.normalize({
      'big' => {'jobs' => 5},
      'timble' => 3.2
    })).to eq({dodo: 5, bingo: {biscuit: 3.2}})
  end

  it "should not symbolized keys in value hashes" do
    expect(MixedMappings.normalize({
      'big' => {'jobs' => 5},
      'timble' => {'string key' => 'value'}
    })).to eq({dodo: 5, bingo: {biscuit: {'string key' => 'value'}}})
  end

end

class DefaultValues
  extend HashMapper

  map from('/without_default'), to('not_defaulted')
  map from('/with_default'),    to('defaulted'), default: 'the_default_value'
end

describe "default values" do
  it "should use a default value whenever a key is not set" do
    expect(DefaultValues.normalize({
      'without_default' => 'some_value'
    })).to eq({ not_defaulted: 'some_value', defaulted: 'the_default_value' })
  end

  it "should not use a default if a key is set (even if the value is falsy)" do
    expect(DefaultValues.normalize({
        'without_default' => 'some_value',
        'with_default' => false
      })).to eq({ not_defaulted: 'some_value', defaulted: false })
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
    expect(MultiBeforeFilter.normalize({ foo: 'X' })).to eq({ bar: 'XYZ' })
  end

  it 'runs before_denormalize filters in the order they are defined' do
    expect(MultiBeforeFilter.denormalize({ bar: 'X' })).to eq({ foo: 'BAX' })
  end

  context 'when the filters are spread across classes' do
    it 'runs before_normalize filters in the order they are defined' do
      expect(MultiBeforeFilterSubclass.normalize({ foo: 'X' })).to eq({ bar: 'XYZ!' })
    end

    it 'runs before_denormalize filters in the order they are defined' do
      expect(MultiBeforeFilterSubclass.denormalize({ bar: 'X' })).to eq({ foo: 'CBAX' })
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
    expect(MultiAfterFilter.normalize({ baz: '0' })).to eq({ bat: '012' })
  end

  it 'runs after_denormalize filters in the order they are defined' do
    expect(MultiAfterFilter.denormalize({ bat: '0' })).to eq({ baz: '890' })
  end

  context 'when the filters are spread across classes' do
    it 'runs after_normalize filters in the order they are defined' do
      expect(MultiAfterFilterSubclass.normalize({ baz: '0' })).to eq({ bat: '0123' })
    end

    it 'runs after_denormalize filters in the order they are defined' do
      expect(MultiAfterFilterSubclass.denormalize({ bat: '0' })).to eq({ baz: '7890' })
    end
  end
end

class WithOptions
  extend HashMapper

  before_normalize do |input, output, opts|
    output[:bn] = opts[:bn] if opts[:bn]
    input
  end

  after_normalize do |input, output, opts|
    output[:an] = opts[:an] if opts[:an]
    output
  end

  before_denormalize do |input, output, opts|
    output[:bdn] = opts[:bdn] if opts[:bdn]
    input
  end

  after_denormalize do |input, output, opts|
    output[:adn] = opts[:adn] if opts[:adn]
    output
  end
end

describe 'with options' do
  context 'when called with options' do
    it 'passes the options to all the filters' do
      expect(WithOptions.normalize({}, options: { bn: 1, an: 2 })).to eq({bn: 1, an: 2})
      expect(WithOptions.denormalize({}, options: { bdn: 1, adn: 2 })).to eq({bdn: 1, adn: 2})
    end
  end

  context 'when called without options' do
    it 'stills work' do
      expect(WithOptions.normalize({})).to eq({})
      expect(WithOptions.denormalize({})).to eq({})
    end
  end
end

describe 'passing custom context object' do
  it 'passes context object down to sub-mappers' do
    friend_mapper = Class.new do
      extend HashMapper

      map from('/name'), to('/name')

      def normalize(input, context: , **kargs)
        context[:names] ||= []
        context[:names] << input[:name]
        self.class.normalize(input, context: context, **kargs)
      end
    end

    mapper = Class.new do
      extend HashMapper

      map from('/friends'), to('/friends'), using: friend_mapper.new
    end

    input = {friends: [{name: 'Ismael', last_name: 'Celis'}, {name: 'Joe'}]}
    ctx = {}
    mapper.normalize(input, context: ctx)
    expect(ctx[:names]).to eq(%w(Ismael Joe))
  end
end

describe 'passing context down to filters' do
  it 'yields context to filters' do
    mapper = Class.new do
      extend HashMapper

      map from('/name'), to('/name', &(->(name, ctx) { "#{ctx[:title]} #{name}" }))
      map from('/age'), to('/age') do |age, ctx|
        "#{age} #{ctx[:age_suffix]}"
      end
    end

    output = mapper.normalize({ name: 'Ismael', age: 43 }, context: { title: 'Mr.', age_suffix: 'years old' })
    expect(output).to eq({ name: 'Mr. Ismael', age: '43 years old' })
  end
end
