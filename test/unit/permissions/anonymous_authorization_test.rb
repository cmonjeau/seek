require 'test_helper'
# Authorization tests that are specific to public access
class AnonymousAuthorizationTest < ActiveSupport::TestCase
  test "anonymous can access 'EVERYONE' scoped sop" do
    fully_public_policy = Factory(:policy, access_type: Policy::EDITING)
    sop = Factory :sop, policy: fully_public_policy
    assert_equal Policy::EDITING, sop.policy.access_type

    assert Seek::Permissions::Authorization.is_authorized?('view', sop, nil)
    assert Seek::Permissions::Authorization.is_authorized?('edit', sop, nil)
    assert Seek::Permissions::Authorization.is_authorized?('download', sop, nil)
    assert !Seek::Permissions::Authorization.is_authorized?('manage', sop, nil)

    assert sop.can_view?
    assert sop.can_edit?
    assert sop.can_download?
    assert !sop.can_manage?
  end

  test "anonymous can access 'ALL_USERS' scoped sop" do
    sop = Factory :sop, policy: Factory(:all_sysmo_downloadable_policy)

    assert_equal Policy::ACCESSIBLE, sop.policy.access_type

    assert Seek::Permissions::Authorization.is_authorized?('view', sop, nil)
    assert !Seek::Permissions::Authorization.is_authorized?('edit', sop, nil)
    assert Seek::Permissions::Authorization.is_authorized?('download', sop, nil)
    assert !Seek::Permissions::Authorization.is_authorized?('manage', sop, nil)

    assert sop.can_view?
    assert !sop.can_edit?
    assert sop.can_download?
    assert !sop.can_manage?
  end

  test 'anonymous can view but not edit or access publicly viewable sop' do
    User.current_user = nil
    sop = Factory :sop, policy: Factory(:policy, access_type: Policy::VISIBLE)

    assert sop.can_view?
    assert !sop.can_edit?
    assert !sop.can_download?
    assert !sop.can_manage?
  end

  test 'anonymous can view and download but not edit publicly viewable sop' do
    User.current_user = nil
    sop = Factory :sop, policy: Factory(:policy, access_type: Policy::ACCESSIBLE)

    assert sop.can_view?
    assert sop.can_download?
    assert !sop.can_edit?
    assert !sop.can_manage?
  end

  test 'anonymous user allowed to perform an action' do
    # it doesn't matter for this test case if any permissions exist for the policy -
    # these can't affect anonymous user; hence can only check the final result of authorization
    fully_public_policy = Factory(:policy, access_type: Policy::EDITING)
    sop = Factory :sop, policy: fully_public_policy
    # verify that the policy really provides access to anonymous users
    temp2 = sop.policy.access_type
    assert temp2 > Policy::NO_ACCESS, 'policy should provide some access for anonymous users for this test'

    res = Seek::Permissions::Authorization.is_authorized?('edit', sop, nil)
    assert res, "anonymous user should have been allowed to 'edit' the SOP - it uses fully public policy"
  end

  test 'anonymous user not authorized to perform an action' do
    # it doesn't matter for this test case if any permissions exist for the policy -
    # these can't affect anonymous user; hence can only check the final result of authorization

    public_download_and_no_custom_sharing_policy =  Factory :policy, access_type: Policy::NO_ACCESS, use_whitelist: false, use_blacklist: false
    sop_with_public_download_and_no_custom_sharing = Factory :sop, policy: public_download_and_no_custom_sharing_policy

    res = Seek::Permissions::Authorization.is_authorized?('view', sop_with_public_download_and_no_custom_sharing, nil)
    assert !res, "anonymous user shouldn't have been allowed to 'view' the SOP - policy authorizes only registered users"
  end
end
