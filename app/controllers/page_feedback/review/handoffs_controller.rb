# frozen_string_literal: true

module PageFeedback
  module Review
    # The page a phone opens after scanning an export's QR codes. The export
    # travels in the URL fragment, which never reaches the server; the page's
    # script reassembles and inflates it in the browser.
    class HandoffsController < BaseController
      # Render the unpacking page.
      #
      # @return [void]
      def show; end
    end
  end
end
