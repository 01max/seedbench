module Releases
  class Queue
    PAGE_SIZE = 40
    STATES = { "all" => "Tous les états", "review" => "À vérifier", "inspection" => "À inspecter",
      "prepared" => "Préparés", "published" => "Publiés", "duplicate" => "Doublons" }.freeze
    Page = Data.define(:records, :selected, :total, :page, :pages, :position, :previous_id, :next_id, :criteria)

    def self.call(q: "", state: "all", page: 1, release_id: nil)
      new(q: q, state: state, page: page, release_id: release_id).call
    end

    def initialize(q:, state:, page:, release_id:)
      @criteria = { q: q.to_s.strip.first(200), state: STATES.key?(state) ? state : "all" }
      @scope = filter(search(Release.all)).order(:id)
      @page = [ page.to_i, 1 ].max
      @selected = Release.find(release_id) if release_id.present?
    end

    def call
      @total = @scope.count
      locate_page
      records = @scope.includes(:payload_revisions, :duplicate_decisions).offset((@page - 1) * PAGE_SIZE).limit(PAGE_SIZE).to_a
      @selected ||= records.first
      @position ||= records.index(@selected) + 1 + ((@page - 1) * PAGE_SIZE) if records.include?(@selected)
      Page.new(records: records, selected: @selected, total: @total, page: @page, pages: @pages, position: @position,
        previous_id: neighbor("<", :desc), next_id: neighbor(">", :asc), criteria: @criteria)
    end

    private

    def locate_page
      @position = @scope.where(id: ..@selected.id).count if @selected && @scope.exists?(@selected.id)
      @page = ((@position - 1) / PAGE_SIZE) + 1 if @position
      @pages = [ (@total.to_f / PAGE_SIZE).ceil, 1 ].max
      @page = [ @page, @pages ].min
    end

    def search(scope)
      return scope if @criteria[:q].empty?

      term = "%#{Release.sanitize_sql_like(@criteria[:q])}%"
      scope.where("title LIKE :term ESCAPE '\\' OR author LIKE :term ESCAPE '\\'", term: term)
    end

    def filter(scope)
      case @criteria[:state]
      when "review" then scope.where.not(publication_state: "published")
      when "inspection" then scope.where(inspection_state: %w[pending running failed])
      when "prepared" then scope.where(preparation_state: "prepared")
      when "published" then scope.where(publication_state: "published")
      when "duplicate" then scope.where(id: DuplicateDecision.where(decision: "confirmed").select(:release_id))
      else scope
      end
    end

    def neighbor(comparison, order)
      @scope.where("id #{comparison} ?", @selected.id).reorder(id: order).pick(:id) if @selected
    end
  end
end
