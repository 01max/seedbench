require 'rails_helper'

RSpec.describe Releases::MarkCheck do
  let(:release) { Releases::Create.call(title: 'Synthetic') }

  def mark(checked, **options)
    described_class.call(release_id: release.id, key: 'text_review', expected_revision: 0, checked: checked, **options)
  end

  it 'freely checks and unchecks manual work with immutable history' do
    mark(true)
    mark(false)

    expect(release.manual_checks.order(:number).pluck(:checked)).to eq([ true, false ])
    expect(release.release_events.where(name: 'checklist.changed').count).to eq(2)
    expect(release.reload.input_revision).to eq(0)
    expect do
      ApplicationRecord.connection.execute("UPDATE manual_checks SET checked = 0 WHERE id = #{release.manual_checks.first.id}")
    end.to raise_error(ActiveRecord::StatementInvalid, /append-only/)
  end

  it 'does not duplicate an unchanged mark' do
    mark(false)
    2.times { mark(true) }

    expect(release.manual_checks.count).to eq(1)
  end

  it 'rejects forged mechanical marks without changing their measured state' do
    expect { mark(true, key: 'inspection') }.to raise_error(described_class::NotManual)
    expect(release.manual_checks.count).to eq(0)
    expect(release.reload.inspection_state).to eq('pending')
  end

  it 'rejects marks against an older edit revision' do
    Releases::Revise.call(release_id: release.id, expected_revision: 0, changes: { title: 'New title' })

    expect { mark(true) }.to raise_error(Releases::RevisionConflict)
    expect(release.manual_checks.count).to eq(0)
  end

  it 'rolls back the mark if its event cannot be persisted' do
    release
    allow(Releases::RecordEvent).to receive(:call).and_raise('Synthetic event failure')

    expect { mark(true) }.to raise_error('Synthetic event failure')
    expect(release.manual_checks.count).to eq(0)
  end

  it 'rejects replacement insertion with recursive SQLite triggers disabled' do
    record = mark(true)
    connection = ApplicationRecord.connection
    expect do
      connection.execute("INSERT OR REPLACE INTO manual_checks SELECT * FROM manual_checks WHERE id = #{record.id}")
    end.to raise_error(ActiveRecord::StatementInvalid, /append-only/)
    expect(record.reload.checked).to be(true)
  end
end
