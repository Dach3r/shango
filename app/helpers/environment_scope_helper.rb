module EnvironmentScopeHelper
  # The current page narrowed to the member's environment, or widened to every one.
  def environment_scope_path(all:)
    query = request.query_parameters.except("environment")
    query = query.merge("environment" => "all") if all
    query.empty? ? request.path : "#{request.path}?#{query.to_query}"
  end
end
