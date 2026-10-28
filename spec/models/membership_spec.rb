require "rails_helper"

RSpec.describe Membership do
  subject(:membership) { create(:membership) }

  it { is_expected.to belong_to(:user) }
  it { is_expected.to belong_to(:project) }
  it { is_expected.to define_enum_for(:role).with_values(member: "member", owner: "owner").backed_by_column_of_type(:string) }

  it { is_expected.to define_enum_for(:folder_toggle).with_values(click: "click", double_click: "double_click").with_prefix.backed_by_column_of_type(:string) }

  it { is_expected.to define_enum_for(:request_open).with_values(click: "click", double_click: "double_click").with_prefix.backed_by_column_of_type(:string) }

  it { is_expected.to define_enum_for(:color_scheme).with_values(system: "system", light: "light", dark: "dark").with_prefix.backed_by_column_of_type(:string) }

  it { is_expected.to define_enum_for(:theme).with_values(Membership::THEMES).with_prefix.backed_by_column_of_type(:string) }

  it "follows the OS color scheme with the default theme by default", :aggregate_failures do
    expect(membership).to be_color_scheme_system
    expect(membership).to be_theme_default
  end

  it "opens requests on single click by default" do
    expect(membership).to be_request_open_click
  end

  it "toggles folders on double click by default" do
    expect(membership).to be_folder_toggle_double_click
  end

  it "collapses nested folders by default" do
    expect(membership.collapse_nested_folders).to be(true)
  end

  describe "uniqueness" do
    it "rejects a second active membership for the same user and project", :aggregate_failures do
      duplicate = build(:membership, user: membership.user, project: membership.project)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors).to include(:user_id)
    end

    it "allows re-adding after a revocation" do
      membership.revoke!

      expect(build(:membership, user: membership.user, project: membership.project)).to be_valid
    end
  end

  describe "#active?" do
    it "is true until revoked", :aggregate_failures do
      expect(membership).to be_active
      membership.revoke!
      expect(membership).not_to be_active
    end
  end

  describe ".active" do
    it "excludes revoked memberships" do
      create(:membership, :revoked)

      expect(described_class.active).to contain_exactly(membership)
    end
  end

  describe "the last owner" do
    let(:project) { create(:project) }
    let!(:owner) { create(:membership, :owner, project:) }

    it "cannot be revoked or demoted", :aggregate_failures do
      expect(owner.update(revoked_at: Time.current)).to be(false)
      expect(owner.errors[:base]).to include(I18n.t("activerecord.errors.models.membership.attributes.base.last_owner"))

      owner.reload
      expect(owner.update(role: :member)).to be(false)
      expect { owner.reload.revoke! }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it "can step down once another owner exists", :aggregate_failures do
      create(:membership, :owner, project:)

      expect(owner.update(role: :member)).to be(true)
      expect(project.memberships.active.owner.count).to eq(1)
    end

    it "does not block members or owners of other projects", :aggregate_failures do
      member = create(:membership, project:)
      other_owner = create(:membership, :owner)

      expect(member.update(revoked_at: Time.current)).to be(true)
      expect(other_owner.update(role: :member)).to be(false)
    end

    it "lets owners change preferences", :aggregate_failures do
      expect(owner.update(theme: "blue")).to be(true)
    end

    it "ignores memberships that were already revoked" do
      revoked = create(:membership, :owner, :revoked, project:)

      expect(revoked.update(role: :member)).to be(true)
    end
  end

  describe "invalid values" do
    it "adds validation errors instead of raising", :aggregate_failures do
      membership.assign_attributes(folder_toggle: "x", request_open: "x", color_scheme: "x", theme: "x")

      expect(membership).not_to be_valid
      expect(membership.errors.attribute_names).to include(:folder_toggle, :request_open, :color_scheme, :theme)
    end

    it "rejects an unknown role" do
      expect { build(:membership, role: "admin") }.to raise_error(ArgumentError)
    end
  end

  describe "database constraints" do
    %w[role folder_toggle request_open color_scheme theme].each do |column|
      it "rejects a #{column} outside the CHECK list" do
        expect { described_class.transaction(requires_new: true) { membership.update_column(column, "bogus") } }.to raise_error(ActiveRecord::StatementInvalid, /check/i)
      end
    end

    it "rejects two active memberships of the same user in a project at the DB level" do
      duplicate = build(:membership, user: membership.user, project: membership.project)

      expect { duplicate.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end
end
