require "rails_helper"

RSpec.describe Users::Destroy do
  let(:user) { create(:user) }
  let(:password) { "password123" }

  def call(password: self.password)
    described_class.call(user:, password:)
  end

  it "destroys the user and the projects only they belong to", :aggregate_failures do
    project = create(:project)
    create(:membership, :owner, user:, project:)

    expect { expect(call).to be_success }.to change(User, :count).by(-1).and change(Project, :count).by(-1)
    expect(Project.exists?(project.id)).to be(false)
  end

  it "keeps projects where the user is a plain member", :aggregate_failures do
    project = create(:project)
    create(:membership, :owner, project:)
    create(:membership, user:, project:)

    expect { expect(call).to be_success }.to change(User, :count).by(-1)
    expect(project.reload.memberships.active.count).to eq(1)
  end

  it "keeps shared projects that have another owner", :aggregate_failures do
    project = create(:project)
    create(:membership, :owner, user:, project:)
    create(:membership, :owner, project:)

    expect(call).to be_success
    expect(Project.exists?(project.id)).to be(true)
  end

  it "destroys a project whose only other memberships were revoked" do
    project = create(:project)
    create(:membership, :owner, user:, project:)
    create(:membership, :revoked, project:)

    expect { call }.to change(Project, :count).by(-1)
  end

  it "refuses when the user is the only owner of a project with other members", :aggregate_failures do
    project = create(:project, name: "Shared")
    create(:membership, :owner, user:, project:)
    create(:membership, project:)

    result = call

    expect(result).to be_failure
    expect(result).to have_attributes(error: :sole_owner, data: { projects: ["Shared"] })
    expect(User.exists?(user.id)).to be(true)
  end

  it "does not destroy anything when one of several projects blocks", :aggregate_failures do
    solo = create(:project)
    shared = create(:project)
    create(:membership, :owner, user:, project: solo)
    create(:membership, :owner, user:, project: shared)
    create(:membership, project: shared)

    expect { call }.not_to change(Project, :count)
    expect(Project.exists?(solo.id)).to be(true)
  end

  it "refuses a wrong or missing password", :aggregate_failures do
    expect(call(password: "nope")).to have_attributes(failure?: true, error: :wrong_password)
    expect(call(password: nil)).to have_attributes(failure?: true, error: :wrong_password)
    expect(User.exists?(user.id)).to be(true)
  end
end
