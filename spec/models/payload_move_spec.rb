require 'rails_helper'

RSpec.describe PayloadMove do
  around { |example| with_preparation_storage { example.run } }

  let(:release) { staged_preparation_release }
  let(:operation) { preparation_operation(release) }
  let(:move) { Preparation::Reserve.call(operation: operation, payload: release.payload_revisions.sole, destination: 'Book.epub') }

  it 'retains immutable journal identity through SQL updates, deletion and replacement attempts' do
    id = move.id
    connection = ApplicationRecord.connection
    expect { connection.execute("UPDATE payload_moves SET source_inode = 0 WHERE id = #{id}") }.to raise_error(ActiveRecord::StatementInvalid, /immutable/)
    expect { connection.execute("DELETE FROM payload_moves WHERE id = #{id}") }.to raise_error(ActiveRecord::StatementInvalid, /retained/)
    expect { connection.execute("INSERT OR REPLACE INTO payload_moves SELECT * FROM payload_moves WHERE id = #{id}") }.to raise_error(ActiveRecord::RecordNotUnique)
    expect(described_class.find(id).source_locator).to eq(move.source_locator)
  end

  it 'permits state progress while refusing cross-release file and operation references' do
    move.update!(state: 'moved')
    expect(move.reload.state).to eq('moved')
    other = staged_preparation_release
    attributes = move.attributes.except('id').merge('release_id' => other.id,
      'workflow_operation_id' => preparation_operation(other).id, 'destination_locator' => 'Other.epub')
    connection = ApplicationRecord.connection
    columns = attributes.keys.map { |key| connection.quote_column_name(key) }.join(', ')
    values = attributes.values.map { |value| connection.quote(value) }.join(', ')
    expect { connection.execute("INSERT INTO payload_moves (#{columns}) VALUES (#{values})") }.to raise_error(ActiveRecord::InvalidForeignKey)
  end
end
