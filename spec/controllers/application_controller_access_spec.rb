require "rails_helper"

RSpec.describe ApplicationController, type: :controller do
  controller do
    def index
      render plain: "Protected artifact bytes"
    end

    def create
      render plain: "Private action executed"
    end
  end

  it "protects artifact responses inherited from the application controller" do
    get :index

    expect(response).to redirect_to("/session/new")
    expect(response.body).not_to include("Protected artifact bytes")
  end

  it "protects inherited action endpoints" do
    post :create

    expect(response).to redirect_to("/session/new")
    expect(response.body).not_to include("Private action executed")
  end
end
