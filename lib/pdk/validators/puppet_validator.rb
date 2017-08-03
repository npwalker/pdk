require 'pdk'
require 'pdk/cli/exec'
require 'pdk/validators/base_validator'
require 'pdk/validators/puppet/puppet_lint'
require 'pdk/validators/puppet/puppet_syntax'

module PDK
  module Validate
    class PuppetValidator < BaseValidator
      def self.name
        'puppet'
      end

      def self.puppet_validators
        [PuppetSyntax, PuppetLint]
      end

      def self.invoke(*args)
        exit_code = 0

        puppet_validators.each do |validator|
          exit_code = validator.invoke(*args)
          break if exit_code != 0
        end

        exit_code
      end
    end
  end
end
