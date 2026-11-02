import { Application } from "@hotwired/stimulus"
import CopyController from "page_feedback/controllers/copy_controller"
import HandoffController from "page_feedback/controllers/handoff_controller"

// Review pages render inside the engine's own layout, so the host's Stimulus
// application is never on the page. Start one scoped to the review UI.
const application = Application.start()
application.register("page-feedback-copy", CopyController)
application.register("page-feedback-handoff", HandoffController)

export { application }
