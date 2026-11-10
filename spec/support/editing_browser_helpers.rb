module EditingBrowserHelpers
  def open_editor(release)
    visit release_path(release)
    find('#workbench[data-editor-ready="true"]')
  end

  def reject_editor_saves
    page.execute_script(<<~JS)
      const original = window.fetch.bind(window)
      window.fetch = (url, options = {}) => options.method === "PATCH"
        ? Promise.resolve(new Response(JSON.stringify({ message: "Échec réseau synthétique" }), { status: 503, headers: { "Content-Type": "application/json" } }))
        : original(url, options)
    JS
  end

  def hold_first_save_response
    page.execute_script(<<~JS)
      const original = window.fetch.bind(window)
      window.fetch = async (url, options = {}) => {
        const response = await original(url, options)
        if (options.method === "PATCH" && !window.saveWasHeld) {
          window.saveWasHeld = true
          document.querySelector('#workbench').dataset.saveHeld = "true"
          await new Promise(resolve => { window.releaseSavedResponse = resolve })
        }
        return response
      }
    JS
  end

  def hold_prepare_response
    page.execute_script(<<~JS)
      const original = window.fetch.bind(window)
      window.fetch = async (url, options = {}) => {
        const response = await original(url, options)
        if (String(url).includes('/actions/prepare')) {
          document.querySelector('#workbench').dataset.prepareHeld = "true"
          await new Promise(resolve => { window.releasePrepareResponse = resolve })
        }
        return response
      }
    JS
  end

  def hold_first_status_response
    page.execute_script(<<~JS)
      const original = window.fetch.bind(window)
      const frame = document.querySelector('turbo-frame[id^="status_release_"]')
      const sequence = frame.querySelector('[data-status-sequence]').dataset.statusSequence
      frame.addEventListener('turbo:before-frame-render', event => {
        if (event.detail.newFrame.querySelector('[data-status-sequence]')?.dataset.statusSequence === sequence) window.oldStatusSeen = true
      })
      frame.addEventListener('turbo:frame-load', () => {
        if (window.oldStatusSeen) frame.dataset.delayedStatusHandled = "true"
      })
      window.fetch = async (url, options = {}) => {
        const response = await original(url, options)
        if (String(url).includes('/status') && !window.statusWasHeld) {
          window.statusWasHeld = true
          document.querySelector('#workbench').dataset.statusHeld = "true"
          await new Promise(resolve => { window.releaseStatusResponse = resolve })
        }
        return response
      }
    JS
  end
end

RSpec.configure { |config| config.include EditingBrowserHelpers, type: :system }
