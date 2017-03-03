module Kontena::Cli
  class SubcommandLoader
    attr_reader :path

    # Create a subcommand loader instance
    #
    # @param [String] path path to command definition
    def initialize(path)
      @path = path
    end

    # Takes something like /foo/bar/cli/master/foo_coimmand and returns [:Master, :FooCommand]
    #
    # @param path [String]
    # @return [Array<Symbol>]
    def constantize(path)
      path.gsub(/.*\/cli\//, '').split('/').map do |path_part|
        path_part.split('_').map{ |e| e.capitalize }.join
      end.map(&:to_sym)
    end

    # Takes an array such as [:Foo] or [:Cli, :Foo] and returns [:Kontena, :Cli, :Foo]
    def kontenaize(tree)
      [:Kontena, :Cli] + (tree - [:Cli])
    end

    # Takes an array such as [:Master, :FooCommand] and returns Master::FooCommand or if not defined, Kontena::Cli::Master::FooCommand
    #
    # @param tree [Array<Symbol]
    # @return [Class]
    def get_class(tree)
      if tree.size == 1
        Object.const_get(tree.first)
      else
        tree[1..-1].inject(Object.const_get(tree.first)) { |new_base, part| new_base.const_get(part) }
      end
    rescue
      raise ArgumentError, "Can't figure out command class name from path #{path} - tried #{tree}"
    end

    def klass
      return @subcommand_class if @subcommand_class
      real_path = path + '.rb' unless path.end_with?('.rb')
      if File.exist?(real_path)
        require(real_path)
      elsif File.exist?(Kontena.cli_root(real_path))
        require(Kontena.cli_root(real_path))
      else
        raise ArgumentError, "Can not load #{real_path} or #{Kontena.cli_root(real_path)}"
      end
      @subcommand_class = get_class(kontenaize(constantize(path)))
    end

    def new(*args)
      klass.new(*args)
    end

    def method_missing(meth, *args)
      klass.send(meth, *args)
    end

    def respond_to_missing?(meth)
      klass.respond_to?(meth)
    end

    def const_get(const)
      klass.const_get(const)
    end

    def const_defined?(const)
      klass.const_defined?(const)
    end

    alias_method :class, :klass
  end
end
