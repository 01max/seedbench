require 'rubocop'

module RuboCop
  module Cop
    module Seedbench
      class PrivateClassHelpers < Base
        MSG = 'Use a private section inside class << self instead of private_class_method.'
        RESTRICT_ON_SEND = %i[private_class_method].freeze

        def on_send(node)
          add_offense(node)
        end
      end
    end
  end
end
