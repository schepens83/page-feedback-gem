import { Application } from "@hotwired/stimulus"
import CopyController from "page_feedback/controllers/copy_controller"

// Review pages render inside the engine's own layout, so the host's Stimulus
// application is never on the page. Start one scoped to the review UI.
const application = Application.start()
application.register("page-feedback-copy", CopyController)

export { application }
