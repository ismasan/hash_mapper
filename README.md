[ ![Codeship Status for ismasan/hash_mapper](https://www.codeship.io/projects/85d172c0-4668-0132-e925-7a7d3d72b19b/status)](https://www.codeship.io/projects/45296)

# hash_mapper

* http://ismasan.github.com/hash_mapper/

## DESCRIPTION:

Maps values from hashes with different structures and/or key names. Ideal for normalizing arbitrary data to be consumed by your applications, or to prepare your data for different display formats (ie. json).
 
Tiny module that allows you to easily adapt from one hash structure to another with a simple declarative DSL.

## FEATURES/PROBLEMS:

It is a module so it doesn't get in the way of your inheritance tree.

## SYNOPSIS:

```ruby
class ManyLevels
  extend HashMapper
  map from('/name'),            to('/tag_attributes/name')
  map from('/properties/type'), to('/tag_attributes/type')
  map from('/tagid'),           to('/tag_id')
  map from('/properties/egg'),  to('/chicken')
end

input = 	{
  :name => 'ismael',
  :tagid => 1,
  :properties => {
    :type => 'BLAH',
    :egg => 33
  }
}

ManyLevels.normalize(input)

# outputs:
	{
  :tag_id => 1,
  :chicken => 33,
  :tag_attributes => {
    :name => 'ismael',
    :type => 'BLAH'
  }
}
```

### Uses:

HashMapper was primarily written as a way of mapping data structure in json requests to hashes with structures friendlier to our ActiveRecord models:

```ruby
@article = Article.create( ArticleParams.normalize(params[:weird_article_data]) )
```

You can use HashMapper in your own little hash-like objects:

```ruby
class NiceHash
  include Enumerable
  extend HashMapper
  
  map from('/names/first'), to('/first_name')
  map from('/names/last'), to('/last_name')

  def initialize(input_hash)
    @hash = self.class.normalize(input_hash)
  end

  def [](k)
    @hash[k]
  end

  def []=(k,v)
    @hash[k] = v
  end

  def each(&block)
    @hash.each(&block)
  end
end

@user = User.new(NiceHash.new(params))
```

### Options:

#### Coercing values

You want to make sure an incoming value gets converted to a certain type, so 

```ruby
{'one' => '1', 'two' => '2'}
```

gets translated to

```ruby`
{:one => 1, :two => 2}
```

Do this:

```ruby
map from('/one'), to('/one', &:to_i)
map from('/two'), to('/two', &:to_i)
```

You can pass :to_i, :to_s or anything available method that makes sense. Don't forget the block notation (&).

You guessed it. That means that you can actually pass custom blocks to each to() definition as well. The following is similar to the previous example:

```ruby
map from('/one'), to('/one'){|value| value.to_i}
```

#### Default values

You want to make sure that a value is present in the output (even if it's not in the input) so that:

```ruby
{'one' => '1'}
```

gets translated to

```ruby
{:one => 1, :two => 2}
```

Do this:

```ruby
map from('/two'), to('/two'), default: 2
```

#### Custom value filtering

You want to pass the final value of a key through a custom filter:

```ruby
{:names => {:first => 'Ismael', :last => 'Celis'}} gets translated to {:user => 'Mr. Celis, Ismael'}
```

Do this:

```ruby
map from('/names'), to('/user') do |names|
  "Mr. #{names[1]}, #{names[0]}"
end
```

### Mapping in reverse

Cool, you can map one hash into another, but what if I want the opposite operation?

Just use the denormalize() method instead:

```ruby
input = {:first => 'Mark', :last => 'Evans'}

output = NameMapper.normalize(input) # => {:first_name => 'Mark', :last_name => 'Evans'}

NameMapper.denormalize(output) # => input
```
	
This will work with your block filters and even nested mappers (see below).
	
### Advanced usage
#### Array access
You want:

```ruby
{:names => ['Ismael', 'Celis']}
```

converted to

```ruby
{:first_name => 'Ismael', :last_name => 'Celis'}
```

Do this:

```ruby
map from('/names[0]'), to('/first_name')
map from('/names[1]'), to('/last_name')
```

#### Nested mappers

You want to map nested structures delegating to different mappers:

From this:

```ruby
input = {
	:project 		=> 'HashMapper',
	:url			=> 'http://github.com/ismasan/hash_mapper',
	:author_names	=> {:first => 'Ismael', :last => 'Celis'}
}
```

To this:

```ruby
output = {
	:project_name	=> 'HashMapper',
	:url			=> 'http://github.com/ismasan/hash_mapper',
	:author			=> {:first_name => 'Ismael', :last_name => 'Celis'}
}
```

Define an UserMapper separate from your ProjectMapper, so you reuse them combined or standalone

```ruby
class UserMapper
  extend HashMapper
  map from('/first'),	to('/first_name')
  map from('/last'),		to('/lastt_name')
end

class ProjectMapper
  extend HashMapper
  map from('/project'), 		to('/project_name')
  map from('/url'),			to('/url')
  map from('/author_names'),	to('/author'), using: UserMapper
end
```

Now ProjectMapper will delegate parsing of :author_names to UserMapper

```ruby
ProjectMapper.normalize( input ) # => output
```

Let's say you have a CompanyMapper which maps a hash with an array of employees, and you want to reuse UserMapper to map each employee. You could:

```ruby
class CompanyMapper
  map from('/info/name'), 			to('/company_name')
  map form('/info/address'),			to('/company_address')
  map from('/info/year_founded'),	to('year_founded', :to_i)

  map from('/employees'),			to('employees') do |employees_array|
    employees_array.collect {|emp_hash| UserMapper.normalize(emp_hash)}
  end
end
```

But HashMapper's nested mappers will actually do that for you if a value is an array, so:

```ruby	
map from('/employees'),	to('employees'), using: UserMapper
```
... Will map each employee using UserMapper.

#### Before and after filters

Sometimes you will need some slightly more complex processing on the whole hash, either before or after normalizing/denormalizing.

For this you can use the class methods before_normalize, before_denormalize, after_normalize and after_denormalize.

They all yield a block with 2 arguments - the hash you are mapping from and the hash you are mapping to, e.g.

```ruby
class EggMapper
  map from('/raw'), to('/fried')
  
  before_normalize do |input, output|
    input['raw'] ||= 'please'     # this will give 'raw' a default value 
    input
  end
  
  after_denormalize do |input, output|
    output.to_a        # the denormalized object will now be an array, not a hash!!
  end

end
```

Important: note that for before filters, you need to return the (modified) input, and for after filters, you need to return the output.
Note also that 'output' is correct at the time of the filter, i.e. before_normalize yields 'output' as an empty hash, while after_normalize yields it as an already normalized hash.

   
## REQUIREMENTS:

## TODO:


#### Optimizations

* Get rid of ActiveSupport (used for inherited class variables and HashWithIndifferentAccess)

## INSTALL:


   gem install hash_mapper

## Credits:

* Ismael Celis (Author - http://github.com/ismasan)
* Mark Evans (Contributor - http://github.com/markevans)
* Jdeveloper (Contributor - http://github.com/jdeveloper)
* nightscape (Contributor - http://github.com/nightscape)
* radamanthus (Contributor - http://github.com/radamanthus)

## LICENSE:

(The MIT License)

Copyright (c) 2009 Ismael Celis

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
'Software'), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
