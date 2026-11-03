# frozen_string_literal: true

module PageFeedback
  module Review
    # Imports comments forwarded from another installation. The handoff page
    # decodes the forward link in the browser and posts the payload here after
    # the reviewer has seen a preview.
    class ImportsController < BaseController
      # Create the forwarded comments that are not here yet and show the outcome.
      #
      # @return [void]
      def create
        payload = ForwardPayload.parse(params[:payload].to_s)
        @result = ForwardImport.new(payload).call
        render :create, status: :created
      rescue ForwardPayload::Invalid => e
        @error = e.message
        render :create, status: :unprocessable_content
      end
    end
  end
end
