require 'rails_helper'

RSpec.describe 'Workbench localization' do
  around do |example|
    catalog = I18n.t('workbench', locale: :fr).deep_transform_values { |value| value.is_a?(String) ? "Translated #{value}" : value }
    previous_backend = I18n.backend
    I18n.backend = I18n::Backend::Simple.new
    I18n.backend.store_translations(:en, workbench: catalog)
    I18n.with_locale(:en) { example.run }
  ensure
    I18n.backend = previous_backend
  end

  before { sign_in_operator }

  it 'localizes rendered labels and both Stimulus message catalogs at request time' do
    release = Releases::Create.call(title: 'Synthetic')
    get release_path(release)
    document = response.parsed_body
    editor = JSON.parse(document.at_css('#workbench')['data-editor-messages-value'])
    status = JSON.parse(document.at_css('.release-checklist')['data-status-poll-messages-value'])

    expect(document.at_css('.queue-state').text).to eq('Translated À inspecter')
    expect(document.at_css('#save-status').text).to eq('Translated Enregistré')
    expect(editor.fetch('pending')).to eq('Translated Modifications en attente')
    expect(status.fetch('current')).to eq('Translated État local à jour')
  end

  it 'keeps manual-review behavior independent of the translated owner label' do
    release = Releases::Create.call(title: 'Synthetic')
    post release_checks_path(release), params: { mark: { key: 'text_review', checked: '1', expected_revision: 0 } }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Translated Texte relu', 'Translated Vous', 'Translated Appliquer')
    expect(release.manual_checks.sole.checked).to be(true)
  end

  it 'localizes validation errors instead of returning inline controller or service copy' do
    release = Releases::Create.call(title: 'Synthetic')
    patch release_path(release), params: { edit: { expected_revision: 0, title: '' } }, as: :json

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body.fetch('message')).to eq('Translated Le titre est requis.')
  end
end
