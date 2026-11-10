require 'yaml'

module Ai
  class Prompts
    CONFIG = YAML.safe_load_file(Rails.root.join('config/ai/prompts.yml')).freeze

    def self.call(purpose:)
      shared = CONFIG.fetch('shared')
      task = CONFIG.fetch('tasks').fetch(purpose)
      { 'version' => "#{shared.fetch('version')}/#{task.fetch('version')}",
        'instructions' => shared.fetch('instructions') + task.fetch('instructions') }
    end
  end
end
