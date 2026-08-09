# frozen_string_literal: true

pin "@hotwired/stimulus", to: "stimulus.min.js", preload: true
pin "page_feedback/clipboard", to: "page_feedback/clipboard.js", preload: false
pin "page_feedback/controllers/copy_controller", to: "page_feedback/controllers/copy_controller.js", preload: false
pin "page_feedback/controllers/capture_controller",
    to: "page_feedback/controllers/capture_controller.js",
    preload: false
pin "page_feedback/capture_controller_support", to: "page_feedback/capture_controller_support.js", preload: false
pin "page_feedback/context_recorder", to: "page_feedback/context_recorder.js", preload: false
pin "page_feedback/element_capture", to: "page_feedback/element_capture.js", preload: false
pin "page_feedback/feedback_picker", to: "page_feedback/feedback_picker.js", preload: false
pin "page_feedback/review_highlight", to: "page_feedback/review_highlight.js", preload: false
pin "page_feedback/visual_viewport", to: "page_feedback/visual_viewport.js", preload: false
