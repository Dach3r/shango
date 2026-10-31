# Text and look of the outcomes of assertions and extractors (see ApiClient::Assertions::Describe for the words).
module AutomationHelper
  def outcome_title(outcome)
    ApiClient::Assertions::Describe.title(outcome)
  end

  def outcome_detail(outcome)
    ApiClient::Assertions::Describe.detail(outcome)
  end

  def outcome_icon(outcome)
    { "passed" => "circle-check", "failed" => "circle-x" }.fetch(outcome["status"], "triangle-alert")
  end

  def outcome_tone(outcome)
    { "passed" => "text-emerald-600 dark:text-emerald-400", "failed" => "text-danger" }.fetch(outcome["status"], "text-amber-600 dark:text-amber-400")
  end
end
