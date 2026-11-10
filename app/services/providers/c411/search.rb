module Providers
  class C411
    class Search
      PAGE_SIZE = 100
      MAX_PAGES = 2

      def self.call(connection:, queries:)
        new(connection, queries).call
      end

      def initialize(connection, queries)
        @connection, @queries = connection, queries
        @candidates, @incomplete = [], false
      end

      def call
        @queries.each { |query| search(query) }
        result(@incomplete ? 'incomplete' : 'complete')
      rescue Providers::Failure, Duplicates::Failure => error
        result(@incomplete ? 'incomplete' : 'unavailable').merge('failure_code' => error.code)
      end

      private

      def search(query)
        MAX_PAGES.times do |page|
          feed = fetch(query, page)
          @candidates.concat(feed.candidates)
          @incomplete ||= feed.incomplete
          return true if finished?(feed, page)
          break if feed.count < PAGE_SIZE
        end
        @incomplete = true
      end

      def fetch(query, page)
        parameters = { t: 'search', q: query, cat: '7020', limit: PAGE_SIZE, offset: page * PAGE_SIZE,
          apikey: @connection.credentials.fetch('api_key') }
        response = Http.call(endpoint: @connection.endpoint, path: "/api?#{URI.encode_www_form(parameters)}")
        SearchFeed.call(body: response.body)
      end

      def finished?(feed, page)
        return (page * PAGE_SIZE) + feed.count >= feed.total if feed.total

        feed.count < PAGE_SIZE
      end

      def result(status)
        { 'status' => status, 'candidates' => @candidates.uniq { |candidate| candidate.fetch('key') } }
      end
    end
  end
end
