Rails.application.config.session_store :active_record_store,
  key: "_seedbench_session", expire_after: 12.hours, httponly: true, same_site: :lax, secure_session_only: true

Rails.application.config.to_prepare do
  ActionDispatch::Session::ActiveRecordStore.session_class = BrowserSession
end
