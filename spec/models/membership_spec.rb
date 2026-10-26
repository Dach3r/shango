require "rails_helper"

RSpec.describe Membership do
  subject(:membership) { create(:membership) }

  it { is_expected.to belong_to(:user) }
  it { is_expected.to belong_to(:project) }
  it { is_expected.to define_enum_for(:role).with_values(member: "member", owner: "owner").backed_by_column_of_type(:string) }

  it { is_expected.to define_enum_for(:folder_toggle).with_values(click: "click", double_click: "double_click").with_prefix.backed_by_column_of_type(:string) }

  it { is_expected.to define_enum_for(:request_open).with_values(click: "click", double_click: "double_click").with_prefix.backed_by_column_of_type(:string) }

  it { is_expected.to define_enum_for(:color_scheme).with_values(system: "system", light: "light", dark: "dark").with_prefix.backed_by_column_of_type(:string) }

  it { is_expected.to define_enum_for(:theme).with_values(default: "default", blue: "blue", green: "green", yellow: "yellow", red: "red", ocean: "ocean").with_prefix.backed_by_column_of_type(:string) }

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
end
