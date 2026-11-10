require 'rails_helper'

RSpec.describe 'Cover selection review', type: :system do
  around { |example| with_preparation_storage { example.run } }

  let(:release) { staged_preparation_release }

  def select_local_cover(image)
    choose 'Image sur cet appareil'
    attach_file 'Fichier PNG, JPEG ou WebP (8 Mio maximum)', image
    check 'J’ai vérifié que l’image correspond à cette édition et à sa langue.'
    check 'J’ai vérifié la netteté, les artefacts et les filigranes.'
    click_button 'Retenir cette couverture'
  end

  it 'saves pending prose and retains a reviewed local image without hosting' do
    image = Rails.application.config.x.storage.fetch(:scratch).join('cover.png')
    image.binwrite(cover_bytes(width: 300, height: 450))
    sign_in_browser
    visit release_path(release)
    find('#workbench[data-editor-ready="true"]')
    fill_in 'Présentation', with: 'Présentation humaine conservée.'
    click_button 'Couverture', exact: true
    select_local_cover(image)
    expect(page).to have_text('Couverture retenue · version 1')
    expect(page).to have_text('300 × 450 pixels natifs')
    expect(Releases::EditorValues.call(release: release.reload)['presentation']).to eq('Présentation humaine conservée.')
    expect(release.cover_hostings).to be_empty
    save_workbench_screenshot('cover-selection.png')
  end
end
