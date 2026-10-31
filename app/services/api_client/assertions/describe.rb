module ApiClient
  module Assertions
    # Words for the outcomes kept in `RequestExecution#test_results` and `CollectionRunItem#test_results`. Outcomes store keys, never
    # sentences, so the viewer's language builds the text (views, run reports).
    module Describe
      module_function

      def title(outcome)
        case outcome["kind"]
        when "assertion" then assertion(outcome)
        when "extractor" then extractor(outcome)
        else outcome["name"].to_s
        end
      end

      def detail(outcome)
        return I18n.t("workbench.automation.errors.#{outcome["error"]}", default: outcome["error"].to_s) if outcome["error"].present?
        return if outcome["actual"].blank? || outcome["status"] == "passed"

        I18n.t("workbench.automation.actual", value: outcome["actual"])
      end

      def assertion(outcome)
        [I18n.t("workbench.automation.sources.#{outcome["source"]}"), outcome["target"].presence, I18n.t("workbench.automation.operators.#{outcome["operator"]}"), outcome["expected"].presence].compact.join(" ")
      end

      def extractor(outcome)
        return I18n.t("workbench.automation.extractor_unsaved") if outcome["variable"].blank?

        from = [I18n.t("workbench.automation.sources.#{outcome["source"]}"), outcome["target"].presence].compact.join(" ")
        I18n.t("workbench.automation.extractor_title", variable: outcome["variable"], from:)
      end
    end
  end
end
