require 'rails_helper'

RSpec.describe AiRun do
  let(:release) { reviewed_content_release }
  let(:run) { Ai::Request.call(release_id: release.id, expected_revision: release.input_revision, purpose: 'prose') }

  before { configure_ai(release) }

  it 'guards request identity and retains terminal results through direct SQL' do
    connection = ApplicationRecord.connection
    expect { connection.execute("UPDATE ai_runs SET prompt_version = 'rewritten' WHERE id = #{run.id}") }.to raise_error(ActiveRecord::StatementInvalid)
    run.update!(status: 'failed', error_code: 'http_503')
    expect { connection.execute("UPDATE ai_runs SET status = 'succeeded' WHERE id = #{run.id}") }.to raise_error(ActiveRecord::StatementInvalid)
    expect { connection.execute("DELETE FROM ai_runs WHERE id = #{run.id}") }.to raise_error(ActiveRecord::StatementInvalid)
    expect(run.reload.error_code).to eq('http_503')
  end
end
