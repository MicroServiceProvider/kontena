require 'docker'
require_relative 'common'
require_relative '../logging'

module Kontena
  module ServicePods
    class Terminator
      include Kontena::Logging
      include Common

      attr_reader :service_id, :instance_number

      # @param [String] service_id
      # @param [Integer] instance_number
      # @param [Hash] opts
      def initialize(service_id, instance_number)
        @service_id = service_id
        @instance_number = instance_number
      end

      # @return [Docker::Container]
      def perform
        service_container = get_container(self.service_id, self.instance_number)
        if service_container
          info "terminating service: #{service_container.name_for_humans}"
          emit_service_pod_event("service:remove_instance", "removing service instance #{service_container.name_for_humans}")
          service_container.stop('timeout' => 10)
          service_container.wait
          service_container.delete(v: true)
          emit_service_pod_event("service:remove_instance", "service instance #{service_container.name_for_humans} removed successfully")
        end
        data_container = get_container(self.service_id, self.instance_number, 'volume')
        if data_container
          info "cleaning up service volumes: #{data_container.name}"
          emit_service_pod_event("service:remove_instance", "removing service instance #{service_container.name_for_humans} data volume")
          data_container.delete(v: true)
          emit_service_pod_event("service:remove_instance", "service instance #{service_container.name_for_humans} data volume removed succesfully")
        end

        service_container
      end
    end
  end
end
