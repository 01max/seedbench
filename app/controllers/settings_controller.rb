class SettingsController < ApplicationController
  def show
    @connections = Settings::Overview.call
  end
end
