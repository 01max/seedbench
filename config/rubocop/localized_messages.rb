require 'rubocop'

module RuboCop
  module Cop
    module Seedbench
      class LocalizedMessages < Base
        MSG = 'Move messages to config/locales and use I18n.t (or t).'
        MESSAGE_KEYS = %i[message check_message notice alert subject].freeze

        def on_pair(node)
          key, value = *node
          check(value) if (key.sym_type? || key.str_type?) && MESSAGE_KEYS.include?(key.value.to_sym)
        end

        def on_send(node)
          arguments = node.arguments
          if %i[raise fail].include?(node.method_name)
            arguments.each { |argument| check(argument) }
          elsif node.method_name == :new && node.receiver&.const_type?
            name = node.receiver.const_name
            arguments = arguments.drop(1) if coded_failure?(node) && arguments.size > 1
            arguments.each { |argument| check(argument) } if name.match?(/(?:Error|Failure|Conflict|Invalid|Unsafe|NotAllowed)\z/)
          elsif node.method_name == :render
            arguments.select(&:hash_type?).each do |hash|
              hash.pairs.each { |pair| check(pair.value) if pair.key.sym_type? && %i[plain html body text].include?(pair.key.value) }
            end
          elsif node.method_name == :[]= && node.receiver&.source&.match?(/\Aflash(?:\.now)?\z/)
            check(arguments.last)
          end
        end

        def on_lvasgn(node)
          name, value = *node
          check(value) if value && name.to_s.match?(/(?:\A|_)(?:message|notice|alert)\z/)
        end

        def on_super(node)
          node.arguments.each { |argument| check(argument) }
        end

        private

        def coded_failure?(node)
          name = node.receiver.const_name
          name == 'Providers::Failure' || (name == 'Failure' && node.each_ancestor(:module).any? { |ancestor| ancestor.children.first.const_name == 'Providers' })
        end

        def check(node)
          return unless node.str_type? || node.dstr_type?

          add_offense(node)
        end
      end
    end
  end
end
