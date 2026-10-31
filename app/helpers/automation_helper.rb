# Text for the outcomes of assertions and extractors kept in `RequestExecution#test_results`. Outcomes store keys, never
# sentences, so they follow the viewer's language.
module AutomationHelper
  def outcome_title(outcome)
    case outcome["kind"]
    when "assertion" then assertion_title(outcome)
    when "extractor" then extractor_title(outcome)
    else outcome["name"].to_s
    end
  end

  def outcome_detail(outcome)
    return t("workbench.automation.errors.#{outcome["error"]}", default: outcome["error"].to_s) if outcome["error"].present?
    return if outcome["actual"].blank? || outcome["status"] == "passed"

    t("workbench.automation.actual", value: outcome["actual"])
  end

  def outcome_icon(outcome)
    { "passed" => "circle-check", "failed" => "circle-x" }.fetch(outcome["status"], "triangle-alert")
  end

  def outcome_tone(outcome)
    { "passed" => "text-emerald-600 dark:text-emerald-400", "failed" => "text-danger" }.fetch(outcome["status"], "text-amber-600 dark:text-amber-400")
  end

  private

  def assertion_title(outcome)
    [t("workbench.automation.sources.#{outcome["source"]}"), outcome["target"].presence, t("workbench.automation.operators.#{outcome["operator"]}"), outcome["expected"].presence].compact.join(" ")
  end

  def extractor_title(outcome)
    return t("workbench.automation.extractor_unsaved") if outcome["variable"].blank?

    from = [t("workbench.automation.sources.#{outcome["source"]}"), outcome["target"].presence].compact.join(" ")
    t("workbench.automation.extractor_title", variable: outcome["variable"], from:)
  end
end
