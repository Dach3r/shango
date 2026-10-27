# A heavy account to measure performance the way a real user with a lot of information would feel it: many projects,
# each with collections, nested folders, requests, environments, variables, history, cookies and network runs.
# Development only (db/seeds.rb loads this folder just there). Size it with SEED_<NAME> variables (see SIZES) and
# rebuild it from scratch with SEED_RESET=1. Rows go in with insert_all, so model callbacks do not run; encrypted
# columns are still encrypted.
module Seeds
  class PerformanceAccount
    EMAIL = "perf@shango.test".freeze
    PASSWORD = "password123".freeze
    BATCH = 1000

    SIZES = {
      projects: 25, collections: 6, folders: 18, requests: 70, environments: 4, variables: 40, executions: 4,
      cookies: 30, drafts: 12, tabs: 12, teammates: 5
    }.freeze

    NOUNS = %w[billing catalog checkout inventory orders payments shipping search users reports invoices accounts webhooks
               analytics notifications messages media settings audit tickets reviews coupons carts refunds
               subscriptions].freeze
    ADJECTIVES = %w[Acme Blue Rapid Nimble Solid Bright Quiet Atlas Delta Nova Orbit Pixel Vector Summit Harbor].freeze
    VERBS = { "GET" => %w[List Get Search Export Fetch], "POST" => %w[Create Import Send Verify], "PUT" => %w[Replace Update],
              "PATCH" => %w[Patch Toggle Rename], "DELETE" => %w[Delete Remove Archive], "HEAD" => %w[Check], "OPTIONS" => %w[Probe] }.freeze
    METHODS = (%w[GET] * 8 + %w[POST] * 4 + %w[PUT PATCH PATCH DELETE DELETE HEAD OPTIONS]).freeze
    ENVIRONMENTS = %w[Local Development Staging QA Production Sandbox Demo Canary].freeze
    TARGETS = %w[example.com github.com cloudflare.com wikipedia.org openai.com stripe.com shopify.com netflix.com
                 mozilla.org python.org rubyonrails.org postgresql.org].freeze
    STATUSES = [[200, "OK"], [200, "OK"], [200, "OK"], [201, "Created"], [204, "No Content"], [301, "Moved Permanently"],
                [400, "Bad Request"], [401, "Unauthorized"], [404, "Not Found"], [422, "Unprocessable Content"],
                [500, "Internal Server Error"], [503, "Service Unavailable"]].freeze

    def self.call
      new(sizes: SIZES.keys.to_h { |name| [name, ENV.fetch("SEED_#{name.upcase}", SIZES[name]).to_i] }, reset: ENV["SEED_RESET"].present?).call
    end

    def initialize(sizes:, reset: false)
      @sizes = sizes
      @reset = reset
      @random = Random.new(42)
      @now = Time.current
      @counts = Hash.new(0)
    end

    def call
      if User.exists?(email: EMAIL)
        return puts("   #{EMAIL} already exists; run with SEED_RESET=1 to rebuild it") unless @reset

        wipe
      end

      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      ActiveRecord::Base.transaction { build }
      report(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started)
    end

    private

    def teammate_emails
      Array.new(@sizes[:teammates]) { |index| "perf.teammate#{index + 1}@shango.test" }
    end

    def wipe
      user_ids = User.where(email: [EMAIL, *teammate_emails]).ids
      project_ids = Membership.where(user_id: user_ids).distinct.pluck(:project_id)
      collection_ids = Collection.where(project_id: project_ids).select(:id)
      environment_ids = Environment.where(project_id: project_ids).select(:id)

      ActiveRecord::Base.transaction do
        User.where(id: user_ids).update_all(current_membership_id: nil)
        RequestTab.where(user_id: user_ids).delete_all
        [RequestExecution, NetworkCheck, ApiRequest, Cookie].each { |model| model.where(project_id: project_ids).delete_all }
        Folder.where(collection_id: collection_ids).delete_all
        Collection.where(project_id: project_ids).delete_all
        Variable.where(environment_id: environment_ids).delete_all
        Membership.where(project_id: project_ids).delete_all
        Environment.where(project_id: project_ids).delete_all
        Project.where(id: project_ids).delete_all
        User.where(id: user_ids).delete_all
      end
    end

    def build
      @user = create_user(EMAIL, "Perf", "Tester")
      @teammates = teammate_emails.each_with_index.map { |email, index| create_user(email, "Teammate", (index + 1).to_s) }
      @bodies = Array.new(40) { response_body }

      @sizes[:projects].times { |index| populate(index) }
      first = Membership.find_by!(user: @user, project_id: @first_project_id)
      @user.update_columns(current_membership_id: first.id)
    end

    def create_user(email, first_name, last_name)
      user = User.new(email:, first_name:, last_name:, password: PASSWORD, password_confirmation: PASSWORD)
      user.skip_confirmation!
      user.save!
      @counts[:users] += 1
      user
    end

    def populate(index)
      project_id = SecureRandom.uuid
      @first_project_id ||= project_id
      slug = "#{pick(ADJECTIVES)}-#{pick(NOUNS)}-#{index + 1}".downcase
      insert(Project, [{ id: project_id, name: slug.tr("-", " ").titleize, icon: pick(Project::ICONS), archived_at: nil }])

      environments = environments_for(project_id)
      memberships_for(project_id, index, environments.first&.fetch(:id))
      variables_for(environments)
      requests = collections_for(project_id, slug)
      executions_for(project_id, requests, environments)
      cookies_for(project_id, slug, environments)
      network_checks_for(project_id, environments)
      drafts_for(project_id)
      tabs_for(requests) if project_id == @first_project_id
    end

    def memberships_for(project_id, index, environment_id)
      rows = [{ id: SecureRandom.uuid, user_id: @user.id, project_id:, role: index.even? ? "owner" : "member", current_environment_id: environment_id, revoked_at: nil }]
      rows += @teammates.map { |teammate| { id: SecureRandom.uuid, user_id: teammate.id, project_id:, role: "member", current_environment_id: nil, revoked_at: nil } }
      insert(Membership, rows)
    end

    def environments_for(project_id)
      rows = ENVIRONMENTS.first(@sizes[:environments]).each_with_index.map do |name, position|
        { id: SecureRandom.uuid, project_id:, name:, position: position + 1 }
      end
      insert(Environment, rows)
      rows
    end

    def variables_for(environments)
      rows = environments.flat_map do |environment|
        Array.new(@sizes[:variables]) do |position|
          key = position < NOUNS.size ? "#{NOUNS[position].upcase}_#{position.even? ? "URL" : "TOKEN"}" : "VAR_#{position}"
          { environment_id: environment[:id], key:, value: key.end_with?("URL") ? "https://#{key.downcase.tr("_", "-")}.example.com" : SecureRandom.hex(16),
            secret: key.match?(/TOKEN|KEY|SECRET/), enabled: position % 9 != 0, position: position + 1 }
        end
      end
      insert(Variable, rows.uniq { |row| [row[:environment_id], row[:key]] })
    end

    def collections_for(project_id, slug)
      collections = Array.new(@sizes[:collections]) do |position|
        { id: SecureRandom.uuid, project_id:, name: "#{pick(NOUNS).capitalize} API v#{position + 1}", description: "Seeded collection #{position + 1}",
          position: position + 1, auth_type: "none", auth_config: nil }
      end
      insert(Collection, collections)
      collections.flat_map { |collection| requests_for(project_id, collection, slug) }
    end

    def requests_for(project_id, collection, slug)
      folders = folders_for(collection)
      positions = Hash.new(0)
      requests = Array.new(@sizes[:requests]) do |index|
        folder_id = index % 4 == 0 || folders.empty? ? nil : pick(folders)[:id]
        request_row(project_id:, collection_id: collection[:id], folder_id:, position: positions[folder_id] += 1, slug:, created_at: @now - index.minutes)
      end
      insert(ApiRequest, requests)
      requests
    end

    def folders_for(collection)
      depths = {}
      folders = Array.new(@sizes[:folders]) do |position|
        parent = position < 4 ? nil : pick(depths.select { |_id, depth| depth < 4 }.keys)
        id = SecureRandom.uuid
        depths[id] = parent ? depths[parent] + 1 : 1
        { id:, collection_id: collection[:id], parent_id: parent, name: "#{pick(NOUNS).capitalize} #{position + 1}", position: position + 1, auth_type: "inherit", auth_config: nil }
      end
      insert(Folder, folders)
      folders
    end

    def request_row(project_id:, collection_id:, folder_id:, position:, slug:, created_at:, user_id: nil)
      method = pick(METHODS)
      resource = pick(NOUNS)
      body = %w[POST PUT PATCH].include?(method)
      bearer = @random.rand < 0.25
      { id: SecureRandom.uuid, project_id:, collection_id:, folder_id:, user_id:, name: "#{pick(VERBS[method])} #{resource} #{position}", http_method: method,
        url: "https://api.#{slug}.example.com/v1/#{resource}#{"/{{#{resource}_id}}" unless method == "GET" && position.odd?}", position:,
        query_params: kv_rows("page" => "1", "per_page" => "50", "sort" => "-created_at").first(@random.rand(0..3)),
        headers: kv_rows("Accept" => "application/json", "X-Request-Id" => "{{request_id}}"),
        body_type: body ? "json" : "none", body: body ? JSON.pretty_generate(sample_payload) : nil, body_form: [], graphql_variables: nil,
        auth_type: bearer ? "bearer" : "inherit", auth_config: bearer ? { "token" => SecureRandom.hex(12), "prefix" => "Bearer" } : nil,
        settings: {}, description: nil, created_at:, updated_at: created_at }
    end

    def kv_rows(pairs)
      pairs.map { |key, value| { "key" => key, "value" => value, "enabled" => true, "description" => "" } }
    end

    def sample_payload
      { "name" => "#{pick(ADJECTIVES)} #{pick(NOUNS)}", "quantity" => @random.rand(1..99), "tags" => Array.new(3) { pick(NOUNS) }, "active" => true,
        "address" => { "street" => "#{@random.rand(1..999)} Main St", "city" => "Santiago", "zip" => @random.rand(10_000..99_999).to_s } }
    end

    def response_body
      JSON.generate("data" => Array.new(@random.rand(8..24)) { { "id" => SecureRandom.uuid, "name" => "#{pick(ADJECTIVES)} #{pick(NOUNS)}", "price" => @random.rand(1..9999) / 10.0, "tags" => Array.new(3) { pick(NOUNS) } } },
                    "meta" => { "page" => 1, "per_page" => 50, "total" => @random.rand(100..9999) })
    end

    def executions_for(project_id, requests, environments)
      rows = requests.flat_map do |request|
        Array.new(@sizes[:executions]) do |index|
          status, text = pick(STATUSES)
          body = status == 204 ? nil : pick(@bodies)
          author = index % 5 == 4 && @teammates.any? ? pick(@teammates) : @user
          { id: SecureRandom.uuid, project_id:, api_request_id: request[:id], user_id: author.id, environment_id: pick(environments)[:id],
            http_method: request[:http_method], url: request[:url].gsub(%r{\{\{(\w+)\}\}}, "42"), status:, status_text: text, duration_ms: @random.rand(20..2400), size_bytes: body.to_s.bytesize,
            request_headers: request[:headers], request_body: request[:body], response_headers: kv_rows("Content-Type" => "application/json", "Cache-Control" => "no-store", "X-Trace" => SecureRandom.hex(8)),
            response_body: body, content_type: "application/json", body_truncated: false, body_omitted: false, redirects: [], unresolved_variables: [], error_kind: nil, error_message: nil,
            timings: { "dns" => 4, "tcp" => 11, "tls" => 23, "ttfb" => 80, "download" => 6 }, set_cookies: [], created_at: @now - @random.rand(0..60.days.to_i).seconds }
        end
      end
      insert(RequestExecution, rows)
    end

    def cookies_for(project_id, slug, environments)
      jars = [nil, *environments.map { |environment| environment[:id] }]
      rows = Array.new(@sizes[:cookies]) do |index|
        { id: SecureRandom.uuid, project_id:, environment_id: jars[index % jars.size], domain: "api.#{slug}.example.com", path: index.even? ? "/" : "/v1", name: "cookie_#{index}",
          value: SecureRandom.hex(24), host_only: true, secure: index % 3 == 0, http_only: index.even?, expires_at: index % 4 == 0 ? @now + 30.days : nil }
      end
      insert(Cookie, rows)
    end

    def network_checks_for(project_id, environments)
      rows = NetworkCheck.kinds.keys.flat_map do |kind|
        Array.new(NetworkCheck::KEEP_PER_KIND) do |index|
          target = pick(TARGETS)
          result = stored_result(kind, target)
          { id: SecureRandom.uuid, project_id:, user_id: pick([@user, *@teammates]).id, environment_id: pick(environments)[:id], kind:, target:, input: stored_input(kind, target),
            result:, outcome: Network::Checks::Digest.for(kind, Network::Checks::Codec.load(kind, result)).tone, created_at: @now - (index * 7).minutes }
        end
      end
      insert(NetworkCheck, rows)
    end

    def stored_input(kind, target)
      case kind
      when "dns" then { "domain" => target, "type" => "A", "expected" => "" }
      when "ports" then { "host" => target, "ports" => "22,80,443" }
      else { "host" => target, "port" => "443", "attempts" => "4" }
      end
    end

    def stored_result(kind, target)
      case kind
      when "dns"
        answered = @random.rand(4..8)
        { "host" => target, "type" => "A", "expected" => nil,
          "rows" => Network::Dns::Resolvers::PUBLIC.first(8).each_with_index.map do |resolver, index|
            up = index < answered
            { "name" => resolver.name, "ip" => resolver.ip, "group" => "public", "status" => up ? "ok" : "no_answer", "answers" => up ? ["203.0.113.10"] : [], "ttl" => 60, "ms" => @random.rand(5..90), "match" => nil }
          end,
          "summary" => { "total" => 8, "answered" => answered, "matched" => 0, "agree" => true } }
      when "ports"
        open = @random.rand(0..3)
        { "host" => target, "address" => "203.0.113.9",
          "rows" => [[22, "ssh"], [80, "http"], [443, "https"]].each_with_index.map { |(port, service), index| { "port" => port, "service" => service, "status" => index < open ? "open" : "closed", "ms" => @random.rand(3..60) } },
          "counts" => { "open" => open, "closed" => 3 - open, "filtered" => 0 } }
      else
        received = @random.rand(0..4)
        { "host" => target, "address" => "203.0.113.9", "port" => 443,
          "attempts" => Array.new(4) { |index| { "status" => index < received ? "open" : "filtered", "ms" => index < received ? @random.rand(5..80) : 2000 } },
          "summary" => { "sent" => 4, "received" => received, "loss" => (4 - received) * 25, "min" => 5, "max" => 80, "avg" => 30, "open" => received, "stopped" => false } }
      end
    end

    def drafts_for(project_id)
      rows = Array.new(@sizes[:drafts]) do |index|
        created_at = @now - index.hours
        request_row(project_id:, collection_id: nil, folder_id: nil, position: index + 1, slug: "scratch", created_at:, user_id: @user.id).merge(updated_at: created_at + 30.minutes)
      end
      @drafts = rows
      insert(ApiRequest, rows)
    end

    def tabs_for(requests)
      open = (requests.first(@sizes[:tabs]) + @drafts.first(2)).each_with_index.map do |request, index|
        { user_id: @user.id, api_request_id: request[:id], created_at: @now - (100 - index).minutes }
      end
      insert(RequestTab, open)
    end

    def insert(model, rows)
      rows.each_slice(BATCH) { |slice| model.insert_all!(slice) }
      @counts[model.model_name.human.pluralize] += rows.size
    end

    def pick(list)
      list[@random.rand(list.size)]
    end

    def report(seconds)
      puts "   #{format("%.1f", seconds)}s: #{@counts.map { |name, count| "#{count} #{name.downcase}" }.join(", ")}"
      puts "   Sign in with #{EMAIL} / #{PASSWORD}"
    end
  end
end

Seeds::PerformanceAccount.call
