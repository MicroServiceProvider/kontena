require_relative 'common'

module Stacks
  class Create < Mutations::Command
    include Common

    common_validations

    required do
      model :grid, class: Grid
      string :name, matches: /^(?!-)(\w|-)+$/ # do not allow "-" as a first character
    end

    def validate
      if self.grid.stacks.find_by(name: name)
        add_error(:name, :exists, "#{name} already exists")
        return
      end
      if self.services.size == 0
        add_error(:services, :empty, "stack does not specify any services")
        return
      end
      validate_expose
      validate_volumes
      validate_services
    end

    def validate_services
      sort_services(self.services).each do |s|
        service = s.dup
        validate_service_links(service)
        service[:grid] = self.grid
        outcome = GridServices::Create.validate(service)
        unless outcome.success?
          handle_service_outcome_errors(service[:name], outcome.errors.message, :validate)
        end
      end
    end

    def execute
      attributes = self.inputs.clone
      grid = attributes.delete(:grid)
      stack = Stack.create(name: self.name, grid: grid)
      unless stack.save
        stack.errors.each do |key, message|
          add_error(key, :invalid, message)
        end
        return
      end

      create_volumes(attributes.delete(:volumes))

      services = sort_services(attributes.delete(:services))
      attributes[:services] = services
      attributes[:volumes] = self.volumes
      attributes[:stack_name] = attributes.delete(:stack)
      stack.stack_revisions.create!(attributes)

      create_services(stack, services)

      stack
    end

    # @param [Array<Hash>] volumes
    def create_volumes(volumes)
      return unless volumes
      volumes.each do |volume|
        unless volume[:external]
          outcome = Volumes::Create.run(grid: self.grid, **volume.symbolize_keys)
          unless outcome.success?
            handle_volume_outcome_errors(volume[:name], outcome.errors)
            return
          end
        end
      end
    end

    # @param [Stack] stack
    # @param [Array<Hash>] services
    def create_services(stack, services)
      services.each do |s|
        service = s.dup
        service[:grid] = stack.grid
        service[:stack] = stack
        outcome = GridServices::Create.run(service)
        unless outcome.success?
          handle_service_outcome_errors(service[:name], outcome.errors.message, :create)
        end
      end
    end
  end
end
