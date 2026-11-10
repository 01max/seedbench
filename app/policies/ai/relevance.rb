module Ai
  class Relevance
    class << self
      def current?(run:, context:)
        %w[succeeded stale].include?(run.status) && run.result&.key?('output') && run.request['context'] == context &&
          run.prompt_version == Prompts.call(purpose: run.purpose).fetch('version')
      end

      def prose?(run:, context:, content_ids:, field:)
        current?(run: run, context: context) && run.purpose == 'prose' && %w[presentation notes].include?(field) &&
          run.result.dig('output', field).present? && run.request.fetch('content_bases', {})[field] == content_ids[field]
      end
    end
  end
end
