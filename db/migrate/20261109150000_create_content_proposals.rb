class CreateContentProposals < ActiveRecord::Migration[8.1]
  def change
    create_table :content_proposals do |table|
      table.references :release, null: false, foreign_key: true
      table.string :kind, null: false
      table.integer :input_revision, null: false
      table.json :bodies, null: false, default: {}
      table.json :dependencies, null: false, default: {}
      table.json :bases, null: false, default: {}
      table.timestamps null: false
    end
    add_check_constraint :content_proposals, "kind IN ('replacement', 'cover')", name: 'content_proposal_kind'
    add_check_constraint :content_proposals, 'input_revision >= 0', name: 'content_proposal_revision'
    %w[bodies dependencies bases].each do |field|
      add_check_constraint :content_proposals, "json_valid(#{field}) AND json_type(#{field}) = 'object'", name: "content_proposal_#{field}"
    end
    reversible do |direction|
      direction.up { install_guards }
      direction.down { %w[update delete replace].each { |action| execute "DROP TRIGGER content_proposals_no_#{action}" } }
    end
  end

  private

  def install_guards
    %w[UPDATE DELETE].each do |action|
      execute "CREATE TRIGGER content_proposals_no_#{action.downcase} BEFORE #{action} ON content_proposals BEGIN SELECT RAISE(ABORT, 'Proposal history is append-only'); END"
    end
    execute "CREATE TRIGGER content_proposals_no_replace BEFORE INSERT ON content_proposals WHEN EXISTS (SELECT 1 FROM content_proposals WHERE id = NEW.id) BEGIN SELECT RAISE(ABORT, 'Proposal history is append-only'); END"
  end
end
