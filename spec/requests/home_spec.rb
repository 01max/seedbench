require 'rails_helper'

RSpec.describe 'Application shell' do
  it 'renders the French product shell with local assets' do
    sign_in_operator
    get root_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('<html lang="fr">', 'Seedbench', 'Préparez')
    expect(response.body).to include('type="importmap"', '/assets/tailwind-')
  end

  it 'exposes a boot health check' do
    get rails_health_check_path

    expect(response).to have_http_status(:ok)
  end
end
