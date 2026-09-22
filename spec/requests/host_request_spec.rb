# frozen_string_literal: true

require "rails_helper"

RSpec.describe "PageFeedback host request" do
  after { PageFeedback.reset_configuration! }

  # Building the policy controller hands it the host's request, and
  # `set_request!` writes `controller_instance` back onto that request. Left
  # there, the host's own request points at an engine controller that never
  # ran: `assigns` in a host request spec reads the wrong controller's (empty)
  # ivars, and anything in production reading `controller_instance` after the
  # render sees a foreign controller.
  it "leaves the host's request pointing at the host controller" do
    get "/"

    expect(response).to have_http_status(:ok)
    expect(request.controller_instance).to be_a(PagesController)
  end

  it "leaves it pointing there when the host denies capture too" do
    PageFeedback.configuration.capture_authorizer = ->(_controller) { false }

    get "/"

    expect(response).to have_http_status(:ok)
    expect(request.controller_instance).to be_a(PagesController)
  end
end
