module ApiClient
  module Imports
    # Reads an export from another app (JSON or YAML) and creates its collections, folders, requests and
    # environments in the project, all or nothing. Result#data carries the counts and the warnings.
    class Import
      include Serviceable

      MAX_BYTES = 5.megabytes
      IMPORTERS = {
        postman: Postman, postman_environment: Postman, insomnia: Insomnia, bruno: Bruno, openapi: Openapi, shango: Shango
      }.freeze

      class Failed < StandardError; end

      def initialize(project:, creator:, content:)
        @project = project
        @creator = creator
        @content = content.to_s
        @counts = { collections: 0, folders: 0, requests: 0, environments: 0 }
      end

      private

      def perform
        return failure(:empty) if @content.strip.empty?
        return failure(:too_large, max: MAX_BYTES / 1.megabyte) if @content.bytesize > MAX_BYTES

        data = parse
        return failure(:invalid_content) unless data.is_a?(Hash)
        return failure(:too_complex) if Support.count_nodes(data) > Support::MAX_NODES

        format = Detector.call(data:)
        return format if format.failure?

        imported = import(format.record, data)
        return imported if imported.failure?

        persist(imported.record)
      end

      # Valid JSON/YAML with the wrong shape (a string where an object is expected) must not crash the request.
      def import(format, data)
        IMPORTERS.fetch(format).call(data:)
      rescue TypeError, NoMethodError
        Result.failure(error: I18n.t("workbench.imports.errors.invalid_content"))
      end

      def parse
        text = @content.dup.force_encoding(Encoding::UTF_8).scrub.delete_prefix("﻿")
        JSON.parse(text)
      rescue JSON::ParserError
        begin
          YAML.safe_load(text, permitted_classes: [], aliases: false)
        rescue Psych::Exception, SystemStackError
          nil
        end
      end

      def persist(tree)
        return failure(:nothing_to_import) if tree[:collections].empty? && tree[:environments].empty?

        warnings = tree[:warnings].dup
        ApplicationRecord.transaction do
          tree[:collections].each { |collection| create_collection(collection) }
          tree[:environments].each { |environment| create_environment(environment, warnings) }
        end
        Result.success(nil, **@counts, warnings: warnings.uniq)
      rescue Failed => error
        failure(:failed, message: error.message)
      end

      def create_collection(tree)
        created = Collections::Create.call(project: @project, creator: @creator, attributes: { name: unique_name(tree[:name], @project.collections), description: tree[:description] })
        raise Failed, errors(created) if created.failure?

        @counts[:collections] += 1
        keep_settings(created.record, tree)
        create_children(created.record, tree, nil)
      end

      # Collections::Create takes neither auth nor scripts; formats that carry the collection's own set them afterwards.
      def keep_settings(collection, tree)
        Auth::Assign.call(record: collection, auth_type: tree[:auth_type], auth_config: tree[:auth_config].to_h) if tree[:auth_type]
        collection.assign_attributes(tree.slice(*Support::AUTOMATION_KEYS))
        collection.save! if collection.changed?
      end

      def create_children(collection, tree, parent)
        tree[:folders].each do |folder|
          created = Folders::Create.call(collection:, attributes: folder.slice(:name, :auth_type, :auth_config, *Support::AUTOMATION_KEYS).merge(parent_id: parent&.id))
          raise Failed, errors(created) if created.failure?

          @counts[:folders] += 1
          create_children(collection, folder, created.record)
        end
        tree[:requests].each do |request|
          created = Requests::Create.call(collection:, attributes: request.merge(folder_id: parent&.id))
          raise Failed, errors(created) if created.failure?

          @counts[:requests] += 1
        end
      end

      def create_environment(tree, warnings)
        variables = tree[:variables].select do |variable|
          valid = variable[:key].match?(Variable::KEY_FORMAT)
          warnings << I18n.t("workbench.imports.warnings.variable_skipped", key: variable[:key]) unless valid
          valid
        end
        attributes = { name: unique_name(tree[:name], @project.environments), variables_attributes: variables.reverse.uniq { |variable| variable[:key] }.reverse }
        created = Projects::Environments::Create.call(project: @project, creator: @creator, attributes:)
        raise Failed, errors(created) if created.failure?

        @counts[:environments] += 1
      end

      def unique_name(name, scope)
        taken = scope.pluck(:name).map(&:downcase)
        return name unless taken.include?(name.downcase)

        (2..).lazy.map { |index| "#{name} (#{index})" }.find { |candidate| taken.exclude?(candidate.downcase) }
      end

      def errors(result)
        result.record.errors.full_messages.to_sentence
      end

      def failure(key, **options)
        Result.failure(error: I18n.t("workbench.imports.errors.#{key}", **options))
      end
    end
  end
end
