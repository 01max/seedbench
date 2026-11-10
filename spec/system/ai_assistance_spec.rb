require 'rails_helper'

RSpec.describe 'Optional assistance review', type: :system do
  let(:release) { reviewed_content_release }

  def open_assistance
    visit release_path(release)
    find('#workbench[data-editor-ready="true"]')
    click_button 'Assistance', exact: true
  end

  def request_targeted
    within('.ai-targeted') do
      first('input[type="checkbox"]').check
      fill_in 'Périmètre et raison de l’analyse ciblée', with: 'Comparer seulement cette preuve pour la revue ciblée.'
      click_button 'Demander l’analyse ciblée'
    end
  end

  before do
    configure_ai(release)
    sign_in_browser
  end

  it 'offers prose without changing editors, then accepts it while preserving human BBCode/NFO' do
    before = Releases::EditorValues.call(release: release)
    run = Ai::Request.call(release_id: release.id, expected_revision: release.input_revision, purpose: 'prose')
    stub_request(:post, 'https://api.openai.com/v1/responses').to_return(body: ai_response(ai_output(run.request['pack'], purpose: 'prose')))
    Workflows::Execute.call(operation_id: run.workflow_operation_id)
    open_assistance
    expect(page).to have_text('Une lecture à découvrir au fil des extraits présentés.')
    click_button 'Accepter cette présentation'
    expect(page).to have_text('Suggestion acceptée après votre revue.')
    values = Releases::EditorValues.call(release: release.reload)
    expect(values.slice('bbcode', 'nfo')).to eq(before.slice('bbcode', 'nfo'))
    expect(values['presentation']).to eq(run.reload.result.dig('output', 'presentation'))
    save_workbench_screenshot('ai-prose-review.png')
  end

  it 'saves pending prose before a request and preserves edits when the provider fails' do
    open_assistance
    click_button 'Revue', exact: true
    fill_in 'Présentation', with: 'Présentation humaine préservée même sans IA.'
    click_button 'Assistance', exact: true
    click_button 'Proposer une présentation'
    expect(page).to have_text('Demande enregistrée')
    run = release.ai_runs.where.not(workflow_operation_id: nil).last
    stub_request(:post, 'https://api.openai.com/v1/responses').to_return(status: 503)
    Workflows::Execute.call(operation_id: run.workflow_operation_id)
    click_link 'Actualiser l’assistance'
    expect(page).to have_text('Fournisseur indisponible')
    expect(Releases::EditorValues.call(release: release.reload)['presentation']).to eq('Présentation humaine préservée même sans IA.')
    expect(WebMock).not_to have_requested(:post, %r{c411.org|postimage.org})
  end

  it 'keeps scoped evidence and generation controls inside a narrow screen' do
    open_assistance
    set_workbench_viewport(320)
    find('summary', text: 'Analyse ciblée avec périmètre explicite').click
    expect(page).to have_field('Périmètre et raison de l’analyse ciblée')
    expect(page.evaluate_script('document.documentElement.scrollWidth')).to be <= 320
    save_workbench_screenshot('ai-targeted-mobile.png')
    request_targeted
    expect(page).to have_text('Demande enregistrée')
    expect(release.ai_runs.where.not(workflow_operation_id: nil).last.request.dig('pack', 'scope', 'mode')).to eq('selected')
  ensure
    page.driver.browser.execute_cdp('Emulation.clearDeviceMetricsOverride')
  end
end
