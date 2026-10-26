module ApiClient
  module Imports
    # Validates an auth type/config expressed in Shango's own strategy keys; unknown strategies fall back to inherit.
    module AuthMapper
      module_function

      def call(type, config, warnings)
        key = type.to_s
        return { auth_type: AuthConfigurable::INHERIT, auth_config: {} } if key.blank? || key == "inherit"
        return { auth_type: "none", auth_config: {} } if key == "none"

        unless Auth::Registry.keys.include?(key)
          warnings << I18n.t("workbench.imports.warnings.auth_unsupported", type: key)
          return { auth_type: AuthConfigurable::INHERIT, auth_config: {} }
        end

        { auth_type: key, auth_config: config.to_h.transform_keys(&:to_s).transform_values { |value| value.nil? ? "" : value.to_s } }
      end
    end
  end
end
