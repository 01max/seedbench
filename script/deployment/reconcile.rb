require 'json'

# Checks payloads and remote state for `bin/reconcile-state` before allowing a restored stack to start.
class DeploymentRecovery
  def initialize
    @paths = Preparation::Paths.new
    @marker = @paths.path('.seedbench-restored', kind: :state)
    metadata = JSON.parse(@marker.read)
    abort 'Restore is incomplete. Import the archive into a fresh state directory.' unless metadata['restored'] == true

    @backed_up_at = Time.iso8601(metadata.fetch('backed_up_at'))
    @issues = []
  rescue Preparation::Failure, JSON::ParserError, ArgumentError, KeyError, IOError, SystemCallError
    abort 'A completed restore marker is required.'
  end

  def run(finish:)
    verify_payloads
    verify_submissions
    verify_drafts
    verify_external_operations
    abort @issues.join("\n") if @issues.any?

    if finish
      @marker.unlink
      File.open(@marker.dirname, &:fsync)
      puts 'State reconciliation passed. The web and worker can now start.'
    else
      puts "Recorded payloads and remote identities matched. Review provider history since #{@backed_up_at.iso8601} before finishing recovery."
    end
  end

  private

  def verify_payloads
    Release.find_each do |release|
      payload = release.payload_revisions.order(number: :desc).first
      next unless payload

      Preparation::Identity.call(path: @paths.path(payload.locator), payload: payload)
      Preparation::Validate.call(release: release) if release.preparation_state == 'prepared'
    rescue Preparation::Failure, ActiveRecord::RecordNotFound
      @issues << "Release #{release.id}: canonical file, preparation or mount does not match."
    end
  end

  def verify_submissions
    RemoteSnapshot.where(kind: 'submission').find_each do |snapshot|
      client = Providers::C411::Publications.new(snapshot.provider_connection)
      receipt = client.read(snapshot.remote_content.fetch('info_hash'))&.receipt
      next if receipt && receipt.id.to_s == snapshot.remote_id

      @issues << "Release #{snapshot.release_id}: C411 submission identity does not match."
    rescue Providers::Failure, KeyError, TypeError
      @issues << "Release #{snapshot.release_id}: C411 submission identity could not be verified."
    end
  end

  def verify_drafts
    DraftLink.find_each do |link|
      previous = link.release.remote_snapshots.where(kind: 'draft', remote_id: link.remote_id).order(:id).last!
      actual = read_draft(link)
      unchanged = if previous.remote_deleted
        actual.nil?
      else
        actual && Drafts::Content.remote(actual) == previous.remote_content && actual['updatedAt'].to_s == previous.remote_revision.to_s
      end
      @issues << "Release #{link.release_id}: C411 draft diverged. Review and synchronize it before starting services." unless unchanged
    rescue Providers::Failure, Drafts::Failure, ActiveRecord::RecordNotFound, KeyError
      @issues << "Release #{link.release_id}: C411 draft identity could not be verified."
    end
  end

  def read_draft(link)
    Providers::C411::Drafts.new(link.provider_connection).read(link.remote_id)
  rescue Providers::Failure => error
    raise unless error.code == 'http_404'

    nil
  end

  def verify_external_operations
    active = WorkflowOperation.where(state: %w[pending running outcome_unknown], effect: %w[remote filesystem])
    unresolved_drafts = DraftWrite.where(state: %w[pending sending unknown]).or(DraftWrite.with_unverified_readback).select(:workflow_operation_id)
    active.or(WorkflowOperation.where(id: unresolved_drafts)).find_each do |operation|
      @issues << "Release #{operation.release_id}: external operation #{operation.id} requires reconciliation before it can be resumed."
    end
  end
end

options = ENV.fetch('SEEDBENCH_RECOVERY_MODE', 'check')
abort 'Unknown recovery mode' unless %w[check finish].include?(options)
DeploymentRecovery.new.run(finish: options == 'finish')
