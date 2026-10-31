class ApiRequest < ApplicationRecord
  include Positionable
  include AuthConfigurable
  include TestAutomation

  METHODS = %w[GET POST PUT PATCH DELETE HEAD OPTIONS].freeze
  BODY_TYPES = %w[none json text xml form_urlencoded multipart graphql binary].freeze
  DEFAULT_SETTINGS = { "timeout" => 30, "follow_redirects" => true, "max_redirects" => 5, "verify_ssl" => true, "use_cookie_jar" => true }.freeze
  MAX_TIMEOUT = 120
  MAX_REDIRECTS = 10
  BODY_FORM_EXTRA = %w[type attachment_id upload_token].freeze

  attr_accessor :draft_owner_id

  belongs_to :project
  belongs_to :collection, optional: true
  belongs_to :folder, optional: true

  has_many :request_executions, dependent: :destroy
  has_many :request_tabs, dependent: :destroy
  has_many :request_drafts, dependent: :delete_all
  has_many :latest_executions, dependent: :delete_all

  has_many_attached :body_files
  has_one_attached :binary_body

  before_validation :assign_project
  before_validation :normalize_rows
  before_validation :normalize_settings

  validates :name, presence: true
  validates :http_method, inclusion: { in: METHODS }
  validates :body_type, inclusion: { in: BODY_TYPES }

  validate :folder_belongs_to_collection

  def query_params=(rows)
    super(self.class.clean_rows(rows))
  end

  def headers=(rows)
    super(self.class.clean_rows(rows))
  end

  def body_form=(rows)
    super(self.class.clean_rows(rows, extra: BODY_FORM_EXTRA))
  end

  # A request that is not saved yet lives in a RequestDraft and is rebuilt in memory from it (see Drafts::Build).
  def draft?
    collection_id.nil?
  end

  def untouched_draft?
    draft? && updated_at == created_at
  end

  def to_param
    persisted? ? super : id
  end

  def siblings
    collection.api_requests.where(folder_id:)
  end

  def allowed_auth_types
    [AuthConfigurable::INHERIT, *super]
  end

  def setting(name)
    settings.fetch(name.to_s) { DEFAULT_SETTINGS.fetch(name.to_s) }
  end

  private

  def assign_project
    self.project_id = collection.project_id if collection
  end

  def normalize_rows
    self.query_params = query_params
    self.headers = headers
    self.body_form = body_form
  end

  def normalize_settings
    raw = settings.is_a?(Hash) ? settings.stringify_keys : {}
    self.settings = {
      "timeout" => raw.fetch("timeout", DEFAULT_SETTINGS["timeout"]).to_i.clamp(1, MAX_TIMEOUT),
      "follow_redirects" => ActiveModel::Type::Boolean.new.cast(raw.fetch("follow_redirects", true)) != false,
      "max_redirects" => raw.fetch("max_redirects", DEFAULT_SETTINGS["max_redirects"]).to_i.clamp(0, MAX_REDIRECTS),
      "verify_ssl" => ActiveModel::Type::Boolean.new.cast(raw.fetch("verify_ssl", true)) != false,
      "use_cookie_jar" => ActiveModel::Type::Boolean.new.cast(raw.fetch("use_cookie_jar", true)) != false
    }
  end

  def folder_belongs_to_collection
    errors.add(:folder, :invalid) if folder_id && folder&.collection_id != collection_id
  end

  class << self
    def clean_rows(rows, extra: [])
      list = rows.respond_to?(:values) && !rows.is_a?(Array) ? rows.values : Array(rows)

      list.filter_map do |row|
        row = row.to_h.stringify_keys
        next if row["key"].blank? && row["value"].blank?

        { "key" => row["key"].to_s, "value" => row["value"].to_s, "enabled" => ActiveModel::Type::Boolean.new.cast(row.fetch("enabled", true)) != false,
          "description" => row["description"].to_s }.merge(row.slice(*extra))
      end
    end
  end
end
