module Content
  class Action
    class << self
      def call(release_id:, kind:, expected_revision:, proposal_id: nil)
        arguments = { release_id: release_id, expected_revision: expected_revision }
        case kind
        when 'review_facts' then ReviewFacts.call(**arguments)
        when 'propose_bbcode', 'propose_nfo' then Propose.call(**arguments, kind: kind.delete_prefix('propose_'))
        when 'confirm_bbcode', 'confirm_nfo' then Confirm.call(**arguments, kind: kind.delete_prefix('confirm_'))
        when 'cover' then CoverPatch.call(**arguments)
        when 'accept' then Accept.call(**arguments, proposal_id: proposal_id)
        else raise Propose::InvalidKind, I18n.t('content.errors.invalid_action')
        end
      end
    end
  end
end
