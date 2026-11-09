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

    expect(measured).to include('queue' => 274, 'row' => 28, 'count' => 20, 'background' => 'rgb(29, 27, 37)', 'selected' => 'rgb(64, 48, 73)')
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
    set_workbench_viewport(1024)
    set_workbench_theme('light')
    measured = dimensions
    save_workbench_screenshot('workbench-light-desktop.png')

    expect(measured).to include('background' => 'rgb(241, 238, 245)', 'selected' => 'rgb(233, 221, 239)')
    expect(measured.fetch('overflow')).to be <= measured.fetch('width')
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
