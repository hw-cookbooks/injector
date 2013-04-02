# Injector

Injector is a tool for injecting recipes or blocks into random locations
throughout a Chef run. Injections must be registered, thus registrations
should be done at the start of the run list.

## Usage

A simple block based example:

```ruby
run_list("recipe[ckbk::registration]", "recipe[ckbk::do_stuff]")
```

```ruby
# ckbk::registration

register_injection(:scream) do
  Chef::Log.info 'Oh, hey, proper compile time placement! \o/'
  ruby_block 'scream in log' do
    block do
      Chef::Log.info 'AAAHHHHHHH'
    end
  end
end

ruby_block 'say registration finished' do
  block do
    Chef::Log.info 'registration finished'
  end
end
```

```ruby
# ckbk::do_stuff

ruby_block 'this is before injection' do
  block do
    Chef::Log.info 'before injection'
  end
end

trigger_injection(:scream)

ruby_block 'this is after injection' do
  block do
    Chef::Log.info 'after injection'
  end
end
```

Perhaps you would rather inject a recipe from an available
cookbook instead? Just register the recipe:

```ruby
register_injection(:test_inject, :recipes => ['ckbk::special_recipe'])
```

Or, maybe files located on the system:

```ruby
register_injection(:test_inject, :paths => ['/path/to/recipe.rb'])
```

# Info 
* Repository: https://github.com/hw-cookbooks/injector
* IRC: Freenode @ #heavywater