class GuardImmutableRecordReplacements < ActiveRecord::Migration[8.1]
  TABLES = %w[
    payload_revisions provider_connections preparation_revisions evidence_items
    reviewed_facts fact_evidence_links findings finding_acknowledgements
    cover_revisions cover_hostings content_revisions duplicate_checks
    duplicate_decisions remote_snapshots release_events workflow_operations
  ].freeze

  def up
    TABLES.each do |table|
      replacement_keys(table).each_with_index { |columns, index| create_guard(table, columns, index) }
    end
  end

  def down
    TABLES.each do |table|
      replacement_keys(table).each_index do |index|
        execute "DROP TRIGGER #{connection.quote_table_name(trigger_name(table, index))}"
      end
    end
  end

  private
    def replacement_keys(table)
      natural_keys = connection.indexes(table).select(&:unique).map(&:columns).reject { |columns| columns.include?("id") }
      [ [ connection.primary_key(table) ] ] + natural_keys.sort
    end

    def trigger_name(table, index)
      "#{table}_no_replace_#{index}"
    end

    def create_guard(table, columns, index)
      predicate = columns.map { |column| "#{connection.quote_column_name(column)} = NEW.#{connection.quote_column_name(column)}" }.join(" AND ")
      message = "UNIQUE constraint failed: #{columns.map { |column| "#{table}.#{column}" }.join(', ')}"
      execute <<~SQL.squish
        CREATE TRIGGER #{connection.quote_table_name(trigger_name(table, index))}
        BEFORE INSERT ON #{connection.quote_table_name(table)}
        WHEN EXISTS (SELECT 1 FROM #{connection.quote_table_name(table)} WHERE #{predicate})
        BEGIN SELECT RAISE(ABORT, #{connection.quote(message)}); END;
      SQL
    end
end
