require "rails_helper"
require "tmpdir"

RSpec.describe "Ebook import", type: :system do
  let(:bytes) { "PK\x03\x04\xD2\x00\xFF\r\n".b * 9000 }
  let(:import_directory) { Dir.mktmpdir("seedbench-browser-upload-") }
  let(:import_files) do
    [ "Édition.epub", "Notes.pdf", "Unsupported.zip" ].map do |name|
      File.join(import_directory, name).tap { |path| File.binwrite(path, bytes) }
    end
  end

  after do
    FileUtils.rm_rf(Rails.application.config.x.storage.fetch(:payload).join("staging"))
    FileUtils.remove_entry_secure(import_directory)
  end

  def attach_import_files(paths)
    find('form[data-upload-ready="true"]')
    attach_file("files", paths, visible: :all)
  end

  it "opens the file picker from the single visible import action" do
    sign_in_browser
    find('form[data-upload-ready="true"]')
    page.execute_script(<<~JS)
      document.querySelector('#files').addEventListener('click', event => {
        event.preventDefault()
        document.querySelector('.upload-form').dataset.pickerRequested = 'true'
      }, {once:true})
    JS
    click_button "Importer des ebooks"

    expect(page).to have_css('form[data-picker-requested="true"]')
    expect(page).not_to have_button("Importer", exact: true)
    expect(Release.count).to eq(0)
  end

  it "imports selected binary files automatically and distinguishes acceptance from rejection" do
    sign_in_browser
    attach_import_files(import_files)

    expect(page).to have_css('.flash-message--success[role="status"]', text: "2 fichiers ajoutés")
    expect(page).to have_css('.flash-message--error[role="alert"]', text: "Unsupported.zip")
    expect(PayloadRevision.pluck(:sha256)).to eq([ Digest::SHA256.hexdigest(bytes) ] * 2)
    expect(PayloadRevision.all.map { |payload| Rails.application.config.x.storage.fetch(:payload).join(payload.locator).binread }).to eq([ bytes, bytes ])
    expect(WorkflowOperation.count).to eq(0)
    save_workbench_screenshot("import-results-dark.png")
  end

  it "saves pending text before an automatic import changes the selected book" do
    release = Releases::Create.call(title: "Reviewed book")
    sign_in_browser
    open_editor(release)
    delay_autosave_timer
    fill_in "Présentation", with: "Keep this text with the original book"
    attach_import_files(import_files.first)

    expect(page).to have_field("Titre", with: "Édition")
    expect(release.content_revisions.sole.body).to eq("Keep this text with the original book")
    expect(Release.count).to eq(2)
  end

  it "keeps the selected files available when a pending edit fails validation" do
    release = Releases::Create.call(title: "Reviewed book")
    sign_in_browser
    open_editor(release)
    fill_in "Titre", with: ""
    attach_import_files(import_files.first)
    expect(page).to have_text("Le titre est requis")
    expect(Release.count).to eq(1)
    fill_in "Titre", with: "Corrected book"
    click_button "Importer 1 fichier", exact: true

    expect(page).to have_field("Titre", with: "Édition")
    expect(release.reload.title).to eq("Corrected book")
  end

  it "shows progress and prevents duplicate submission while the upload is pending" do
    sign_in_browser
    page.execute_script(<<~JS)
      const original = window.fetch.bind(window)
      window.fetch = async (url, options) => {
        if (String(url).includes('/uploads')) await new Promise(resolve => { window.allowUpload = resolve })
        return original(url, options)
      }
    JS
    attach_import_files(import_files.first)
    expect(page).to have_button("Importation de 1 fichier…", disabled: true)
    expect(page).to have_css('.upload-form[aria-busy="true"]')
    page.execute_script("window.allowUpload()")
    expect(page).to have_css(".flash-message--success", text: "1 fichier ajouté")
    expect(Release.count).to eq(1)
  end

  it "retains the selected files and offers a deliberate retry after a network failure" do
    sign_in_browser
    page.execute_script(<<~JS)
      window.originalUploadFetch = window.fetch.bind(window)
      window.fetch = (url, options) => String(url).includes('/uploads')
        ? Promise.reject(new TypeError('Synthetic offline failure')) : window.originalUploadFetch(url, options)
    JS
    attach_import_files(import_files.first)
    expect(page).to have_css('.upload-error[role="alert"]', text: "Vérifiez la file")
    expect(page).to have_button("Importer 1 fichier", disabled: false)
    save_workbench_screenshot("import-network-error.png")
    page.execute_script("window.fetch = window.originalUploadFetch")
    click_button "Importer 1 fichier", exact: true
    expect(page).to have_css(".flash-message--success", text: "1 fichier ajouté")
    expect(Release.count).to eq(1)
  end
end
