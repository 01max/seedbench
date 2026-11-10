module Providers
  class Openai
    class Response
      class << self
        def call(data:, purpose:, pack:)
          validate_envelope!(data)
          content = message_content(data.fetch('output'))
          text = content.fetch('text')
          raise Ai::Failure.new(:invalid_output) unless text.is_a?(String) && text.bytesize <= 32_768

          output = Ai::Output.call(purpose: purpose, output: JSON.parse(text), pack: pack)
          { 'output' => output, 'response_model' => data['model'], 'response_id' => data['id'], 'usage' => usage(data) }
        rescue JSON::ParserError, KeyError, TypeError
          raise Ai::Failure.new(:invalid_output), cause: nil
        end

        private

        def validate_envelope!(data)
          raise Ai::Failure.new(:invalid_output) unless data.is_a?(Hash)
          raise Ai::Failure.new(:incomplete) unless data['status'] == 'completed'
          raise Ai::Failure.new(:invalid_output) unless data['model'].is_a?(String) && data['model'].match?(/\A[a-zA-Z0-9_.:-]{1,120}\z/)
          raise Ai::Failure.new(:invalid_output) unless data['id'].is_a?(String) && data['id'].match?(/\Aresp_[a-zA-Z0-9_-]{1,160}\z/)
        end

        def message_content(items)
          raise Ai::Failure.new(:invalid_output) unless output_items?(items)

          messages = items.select { |item| item['type'] == 'message' }
          raise Ai::Failure.new(:invalid_output) unless messages.one? && messages.first['role'] == 'assistant'

          content(messages.first.fetch('content'))
        end

        def output_items?(items)
          allowed = %w[message reasoning]
          items.is_a?(Array) && items.all? { |item| item.is_a?(Hash) && allowed.include?(item['type']) }
        end

        def content(contents)
          raise Ai::Failure.new(:invalid_output) unless contents.is_a?(Array) && contents.all?(Hash)
          raise Ai::Failure.new(:refused) if contents.any? { |item| item['type'] == 'refusal' }
          raise Ai::Failure.new(:invalid_output) unless contents.one? && contents.first['type'] == 'output_text'

          contents.first
        end

        def usage(data)
          return {} unless data['usage'].is_a?(Hash)

          data['usage'].slice('input_tokens', 'output_tokens', 'total_tokens').select { |_, value| value.is_a?(Integer) && value >= 0 }
        end
      end
    end
  end
end
