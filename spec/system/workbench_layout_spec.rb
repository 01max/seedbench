require 'rails_helper'

RSpec.describe 'Dense workbench layout', type: :system do
  let!(:books) { build_workbench_queue }
  let(:selected) { books.fetch(3) }

  before do
    prepare_visual_release(selected)
    sign_in_browser
    open_editor(selected)
  end

  after { page.driver.browser.execute_cdp('Emulation.clearDeviceMetricsOverride') }

  def dimensions
    page.evaluate_script(<<~JS)
      ({ width: innerWidth, overflow: document.documentElement.scrollWidth,
         queue: document.querySelector('.work-queue').getBoundingClientRect().width,
         checklist: document.querySelector('.release-checklist').getBoundingClientRect().width,
         row: document.querySelector('.queue-row').getBoundingClientRect().height,
         background: getComputedStyle(document.body).backgroundColor,
         selected: getComputedStyle(document.querySelector('.queue-row[aria-current]')).backgroundColor,
         count: document.querySelectorAll('.queue-row').length,
         lastRowBottom: document.querySelector('.queue-row:last-child').getBoundingClientRect().bottom,
         footerBottom: document.querySelector('.work-footer').getBoundingClientRect().bottom, height: innerHeight })
    JS
  end

  it 'keeps the compact twenty-row desktop layout and dark Revue palette' do
    set_workbench_viewport(1024)
    set_workbench_theme('dark')
    measured = dimensions
    save_workbench_screenshot('workbench-dark-desktop.png')

    expect(measured).to include('queue' => 274, 'checklist' => 274, 'row' => 28, 'count' => 20, 'background' => 'rgb(29, 27, 37)', 'selected' => 'rgb(64, 48, 73)')
    expect(measured.fetch('overflow')).to be <= measured.fetch('width')
    expect(measured.fetch('lastRowBottom')).to be <= measured.fetch('height')
    expect(measured.fetch('footerBottom')).to be <= measured.fetch('height') + 1
  end

  it 'wraps long unbroken metadata without pushing mobile controls off the page' do
    Releases::Save.call(release_id: selected.id, expected_revision: 1, changes: { title: 'L' * 200 })
    open_editor(selected)
    set_workbench_viewport(320)
    measured = dimensions

    expect(measured.fetch('overflow')).to be <= measured.fetch('width')
    expect(page).to have_button('Enregistrer', exact: true)
  end

  it 'uses the matching light palette without horizontal overflow' do
    set_workbench_viewport(900)
    set_workbench_theme('light')
    measured = dimensions
    save_workbench_screenshot('workbench-light-desktop.png')

    expect(measured).to include('queue' => 238, 'checklist' => 238, 'background' => 'rgb(241, 238, 245)', 'selected' => 'rgb(233, 221, 239)')
    expect(measured.fetch('overflow')).to be <= measured.fetch('width')
  end

  it 'keeps the archive footer in view when C411 rate limits the account' do
    create_connection
    c411 = stub_request(:get, 'https://c411.org/api/user/drafts').to_return(status: 429)
    selected.reload.update!(archived_at: Time.current)
    set_workbench_viewport(1024)
    visit root_path(q: '', state: 'archived', commit: 'Filtrer')
    find('#workbench[data-editor-ready="true"]')
    measured = dimensions

    expect(measured.fetch('footerBottom')).to be <= measured.fetch('height') + 1
    expect(c411).not_to have_been_requested
    click_button 'Restaurer'
    expect(page).to have_button('Archiver')
  end

  [ 320, 390, 736 ].each do |width|
    it "retains the queue, editor, checklist and actions at #{width}px without horizontal scrolling" do
      set_workbench_viewport(width)
      measured = dimensions
      save_workbench_screenshot("workbench-#{width}.png")

      expect(measured.fetch('overflow')).to be <= measured.fetch('width')
      expect(page).to have_field('Titre', with: selected.title)
      expect(page).to have_css('[aria-label="Contrôles de publication"]')
      expect(page).to have_button('Enregistrer', exact: true)
      expect(page).to have_css('.queue-row', count: 20)
    end
  end
end
