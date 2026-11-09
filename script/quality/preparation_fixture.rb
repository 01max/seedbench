module SyntheticPreparation
  module PauseAfterRename
    private

    def rename
      super
      return unless @operation.parameters['pause_after_rename']

      scratch = Rails.application.config.x.storage.fetch(:scratch)
      scratch.join("preparation-renamed-#{@operation.id}").write(@operation.attempt_token)
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 90
      until scratch.join("preparation-continue-#{@operation.id}").exist?
        raise 'Synthetic preparation wait expired' if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline

        sleep 0.05
      end
    end
  end
end

Preparation::Move.prepend(SyntheticPreparation::PauseAfterRename)
