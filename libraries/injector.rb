module InjectorRegistrator
  class << self

    def register_injection(key, args={}, &block)
      args = Mash.new(args)
      @inject_reg ||= Mash.new
      @inject_reg[key] ||= Mash.new
      if(args[:recipes])
        @inject_reg[key][:recipes] = (Array(@inject_reg[key][:recipes]) + Array(args[:recipes])).uniq
      end
      if(args[:paths])
        @inject_reg[key][:paths] = (Array(@inject_reg[key][:paths]) + Array(args[:paths])).uniq
      end
      if(block_given?)
        @inject_reg[key][:blocks] ||= []
        @inject_reg[key][:blocks] << block
      end
      true
    end

    def injection_for(key, type)
      if(@inject_reg && @inject_reg[key] && @inject_reg[key][type])
        @inject_reg[key][type]
      else
        []
      end
    end
  end
end

module InjectorHelper

  module GenericMethods
    def register_injection(*args, &block)
      InjectorRegistrator.register_injection(*args, &block)
    end
    
    def default_injection_order
      %w(recipes paths blocks)
    end
    
    def trigger_injection!(key, override_injection_order=nil)
      Chef::Log.info "Starting custom injection for: #{key}"
      injection_order = override_injection_order || default_injection_order
      Array(injection_order).each do |type|
        InjectorRegistrator.injection_for(key, type).each do |item|
          case type
          when 'recipes'
            parts = item.split('::')
            parts << 'default' unless parts.size > 1
            inject_recipe(*parts)
          when 'paths'
            inject_file(item)
          when 'blocks'
            inject_block(item)
          else
            raise "Unknown injection type requested: #{type}"
          end
        end
      end
      Chef::Log.info "Completed custom injection for: #{key}"
      true
    end
    
    def inject_recipe(cookbook, recipe)
      ckbk = Chef::CookbookLoader.new(Chef::Config[:cookbook_path]).load_cookbooks[cookbook]
      raise "Failed to locate requested cookbook for recipe injection: #{cookbook}" unless ckbk
      rcp_path = ckbk.recipe_filenames_by_name[recipe]
      Chef::Log.info("Injecting recipe: #{cookbook}::#{recipe}")
      inject_file(rcp_path, :no_log)
    end

    module RecipeMethods
      def inject_file(path, *args)
        Chef::Log.info("Injecting file: #{path}") unless args.include?(:no_log)
        raise "Injection file not found! (#{path})" unless ::File.exists?(path)
        from_file(path)
      end

      def inject_block(block)
        Chef::Log.info 'Injecting custom block'
        instance_eval &block
      end
    end

    module ProviderMethods
      def inject_file(path, *args)
        Chef::Log.info("Injecting file: #{path}") unless args.include?(:no_log)
        raise "Injection file not found! (#{path})" unless ::File.exists?(path)
        recipe_eval do
          self.instance_eval(IO.read(path), path, 1)
        end
      end

      def inject_block(block)
        Chef::Log.info 'Injecting custom block'
        recipe_eval &block
      end
    end
  end

  class << self
    include GenericMethods
    include RecipeMethods

    def included(klass)
      klass.send(:include, GenericMethods)
      klass.send(:include, RecipeMethods) if klass == Chef::Recipe
      klass.send(:include, ProviderMethods) if klass == Chef::Provider
    end
  end
end

Chef::Recipe.send(:include, InjectorHelper)
Chef::Provider.send(:include, InjectorHelper)
