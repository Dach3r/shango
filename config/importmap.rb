# Pin npm packages by running ./bin/importmap

pin "application"
pin "submit_loading"
pin "sync_root_attributes"
pin "block_browser_find"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
pin_all_from "app/javascript/lib", under: "lib"
pin "codemirror", to: "codemirror.js", preload: "workbench"
pin "chart.js", to: "chart.js"
