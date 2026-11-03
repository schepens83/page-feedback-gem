# frozen_string_literal: true

module PageFeedback
  module Review
    # Forwards pending feedback to the installation at +config.handoff_url+,
    # where it is imported and reviewed (docs/WORKFLOW.md, "Forwarding").
    class ForwardsController < BaseController
      before_action :ensure_forwarding_configured
      before_action :set_forward, only: :show

      # List earlier forwards, newest first.
      #
      # @return [void]
      def index
        @forwards = Forward.includes(:forward_items).order(created_at: :desc)
      end

      # Show the link that carries one forward to its destination.
      #
      # @return [void]
      def show
        @forward_url = @forward.url(source: instance_name)
        @remaining = forwardable_comments.count
      end

      # Forward the oldest pending comments that were not forwarded yet,
      # limited by the active category when set.
      #
      # @return [void]
      def create
        comments = forwardable_comments.order(:created_at, :id).limit(ForwardPayload::MAX_COMMENTS)
        if comments.none?
          redirect_to review_pages_path(filter: "pending", category: review_category), status: :see_other
          return
        end

        forward = Forward.create_from!(comments:, destination_url: handoff_url, actor: page_feedback_current_actor)
        redirect_to review_forward_path(forward), status: :see_other
      end

      private

      def set_forward
        @forward = Forward.find(params.expect(:id))
      end

      def forwardable_comments
        comments = Comment.awaiting_review
        review_category ? comments.by_category(review_category) : comments
      end

      def handoff_url
        PageFeedback.configuration.handoff_url
      end

      def instance_name
        PageFeedback.configuration.instance_name.presence || request.host
      end

      def ensure_forwarding_configured
        head :not_found if handoff_url.blank?
      end
    end
  end
end
