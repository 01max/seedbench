module WorkbenchFixtures
  TITLES = [
    [ 'Le Comte de Monte-Cristo', 'Alexandre Dumas' ], [ 'Les Trois Mousquetaires', 'Alexandre Dumas' ],
    [ 'L’Île mystérieuse', 'Jules Verne' ], [ 'Vingt mille lieues sous les mers', 'Jules Verne' ],
    [ 'Voyage au centre de la Terre', 'Jules Verne' ], [ 'Le Tour du monde en quatre-vingts jours', 'Jules Verne' ],
    [ 'Germinal', 'Émile Zola' ], [ 'Au Bonheur des Dames', 'Émile Zola' ],
    [ 'Madame Bovary', 'Gustave Flaubert' ], [ 'Salammbô', 'Gustave Flaubert' ],
    [ 'Les Misérables', 'Victor Hugo' ], [ 'Notre-Dame de Paris', 'Victor Hugo' ],
    [ 'Le Rouge et le Noir', 'Stendhal' ], [ 'La Chartreuse de Parme', 'Stendhal' ],
    [ 'Bel-Ami', 'Guy de Maupassant' ], [ 'Une vie', 'Guy de Maupassant' ],
    [ 'Le Père Goriot', 'Honoré de Balzac' ], [ 'Eugénie Grandet', 'Honoré de Balzac' ],
    [ 'La Peau de chagrin', 'Honoré de Balzac' ], [ 'Lettres de mon moulin', 'Alphonse Daudet' ]
  ].freeze

  def build_workbench_queue(count: 20)
    Array.new(count) do |index|
      title, author = TITLES[index % TITLES.size]
      suffix = index >= TITLES.size ? " · #{index + 1}" : ''
      release = Releases::Create.call(title: title + suffix, author: author)
      release.payload_revisions.create!(number: 1, original_filename: "synthetic-#{index}.epub", format: %w[epub pdf mobi][index % 3],
        size_bytes: 2_400_000, sha256: Digest::SHA256.hexdigest("synthetic-#{index}"), locator: "staging/synthetic-#{index}.epub")
      release
    end
  end

  def prepare_visual_release(release)
    Releases::Save.call(release_id: release.id, expected_revision: 0, changes: {
      presentation: 'Le professeur Aronnax découvre le Nautilus et les mystères des profondeurs. Une aventure à relire, entre découvertes scientifiques et horizons lointains.',
      bbcode: "[b]Présentation[/b]\nUne aventure à relire.", nfo: "Titre : #{release.title}\nFormat : EPUB\nÉdition à confirmer" })
    release.findings.create!(payload_revision: release.payload_revisions.sole, code: 'edition_uncertain', number: 1,
      severity: 'uncertainty', message: 'Édition numérique à confirmer', input_revision: 1, data: { source: 'Synthetic edition evidence' })
  end

  def set_workbench_theme(theme)
    page.execute_script("localStorage.setItem('seedbench.appearance', arguments[0])", theme)
    visit current_path
    find("html[data-theme='#{theme}']")
  end

  def save_workbench_screenshot(name)
    return unless ENV['WORKBENCH_SCREENSHOTS'] == '1'

    FileUtils.mkdir_p(Capybara.save_path)
    File.binwrite(File.join(Capybara.save_path, name), page.driver.browser.screenshot_as(:png))
  end

  def set_workbench_viewport(width, height: 824)
    page.driver.browser.execute_cdp('Emulation.setDeviceMetricsOverride', width: width, height: height, deviceScaleFactor: 1, mobile: false)
  end

  def delay_autosave_timer
    page.execute_script(<<~JS)
      const original = window.setTimeout.bind(window)
      window.setTimeout = (callback, delay, ...parameters) => original(callback, delay === 700 ? 10000 : delay, ...parameters)
    JS
  end
end

RSpec.configure { |config| config.include WorkbenchFixtures, type: :system }
