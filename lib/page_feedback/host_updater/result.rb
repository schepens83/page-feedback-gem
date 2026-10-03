# frozen_string_literal: true

module PageFeedback
  class HostUpdater
    # One host repository outcome.
    # @!attribute repo [r] the repository directory
    # @!attribute status [r] one of the documented status symbols
    # @!attribute detail [r] human-readable status detail
    Result = Struct.new(:repo, :status, :detail, keyword_init: true) do
      # @return [Boolean] whether the run should finish successfully; skipped
      #   hosts (`ref_pin`, `dirty`, undeclared) are informational, not errors
      def ok?
        status != :failed
      end
    end
  end
end
