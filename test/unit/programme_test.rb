require 'test_helper'

class ProgrammeTest < ActiveSupport::TestCase

  test 'uuid' do
    p = Programme.new title: 'fish'
    assert_nil p.attributes['uuid']
    disable_authorization_checks { p.save! }
    refute_nil p.attributes['uuid']
    uuid = p.uuid
    p.title = 'frog'
    disable_authorization_checks { p.save! }
    assert_equal uuid, p.uuid
  end

  test 'validation' do
    p = Programme.new
    refute p.valid?
    p.title = 'frog'
    assert p.valid?
    disable_authorization_checks { p.save! }

    # title must be unique
    p2 = Programme.new title: p.title
    refute p2.valid?
    p2.title = 'sdfsdfsdf'
    assert p2.valid?
    assert p2.valid?
  end

  test 'factory' do
    p = Factory :programme
    refute_nil p.title
    refute_nil p.uuid
    refute_empty p.projects
  end

  test 'people via projects' do
    person1 = Factory :person
    person2 = Factory :person
    person3 = Factory :person
    assert_equal 1, person1.projects.size
    assert_equal 1, person2.projects.size
    projects = person1.projects | person2.projects
    prog = Factory :programme, projects: projects
    assert_equal 2, prog.projects.size
    peeps = prog.people
    assert_equal 2, peeps.size
    assert_includes peeps, person1
    assert_includes peeps, person2
    refute_includes peeps, person3
  end

  test 'institutions via projects' do
    person1 = Factory :person
    person2 = Factory :person
    person3 = Factory :person

    projects = person1.projects | person2.projects
    prog = Factory :programme, projects: projects
    assert_equal 2, prog.projects.size
    inst = prog.institutions
    assert_equal 2, inst.size
    assert_includes inst, person1.institutions.first
    assert_includes inst, person2.institutions.first
    refute_includes inst, person3.institutions.first
  end

  test "can delete" do
    admin = Factory(:admin)
    person = Factory(:person)

    programme_administrator = Factory(:programme_administrator)
    programme = programme_administrator.programmes.first

    assert programme.can_delete?(admin)
    refute programme.can_delete?(programme_administrator)
    refute programme.can_delete?(person)
    refute programme.can_delete?(nil)
  end

  test 'can be edited by' do
    admin = Factory(:admin)
    person = Factory(:person)

    programme_administrator = Factory(:programme_administrator)
    programme = programme_administrator.programmes.first

    assert programme.can_be_edited_by?(admin)
    assert programme.can_be_edited_by?(programme_administrator)
    refute programme.can_be_edited_by?(person)
    refute programme.can_be_edited_by?(nil)
  end

  test 'disassociate projects on destroy' do
    programme = Factory(:programme)
    project = programme.projects.first
    assert_equal programme.id, project.programme_id
    User.current_user = Factory(:admin).user
    programme.destroy
    project.reload
    assert_nil project.programme_id
  end

  test 'administrators' do
    person = Factory(:person)
    programme = Factory(:programme)
    refute person.is_programme_administrator?(programme)
    assert_empty programme.administrators
    person.is_programme_administrator = true, programme
    disable_authorization_checks { person.save! }

    assert person.is_programme_administrator?(programme)
    refute_empty programme.administrators
    assert_equal [person], programme.administrators
  end

  test 'assign adminstrator ids' do
    programme = Factory(:programme)
    person = Factory(:person)
    person2 = Factory(:person)

    programme.update_attributes(administrator_ids: [person.id.to_s])
    person.reload
    person2.reload
    programme.reload

    assert person.is_programme_administrator?(programme)
    refute person2.is_programme_administrator?(programme)
    assert_equal [person], programme.administrators

    programme.update_attributes(administrator_ids: [person2.id])
    person.reload
    person2.reload
    programme.reload

    refute person.is_programme_administrator?(programme)
    assert person2.is_programme_administrator?(programme)
    assert_equal [person2], programme.administrators

    programme.update_attributes(administrator_ids: [person2.id, person.id])
    person.reload
    person2.reload
    programme.reload

    assert person.is_programme_administrator?(programme)
    assert person2.is_programme_administrator?(programme)
    assert_equal [person2, person].sort, programme.administrators.sort
  end

  test 'can create' do
    with_config_value :allow_user_programme_creation,true do
      User.current_user = nil
      refute Programme.can_create?

      User.current_user = Factory(:brand_new_person).user
      refute Programme.can_create?

      User.current_user = Factory(:person).user
      assert Programme.can_create?

      User.current_user = Factory(:admin).user
      assert Programme.can_create?
    end

    with_config_value :allow_user_programme_creation,false do
      User.current_user = nil
      refute Programme.can_create?

      User.current_user = Factory(:brand_new_person).user
      refute Programme.can_create?

      User.current_user = Factory(:person).user
      refute Programme.can_create?

      User.current_user = Factory(:admin).user
      assert Programme.can_create?
    end

    with_config_value :programmes_enabled, false do
      User.current_user = nil
      refute Programme.can_create?

      User.current_user = Factory(:brand_new_person).user
      refute Programme.can_create?

      User.current_user = Factory(:person).user
      refute Programme.can_create?

      User.current_user = Factory(:admin).user
      refute Programme.can_create?
    end
  end

  test 'programme activated automatically when created by an admin' do
    User.with_current_user Factory(:admin).user do
      prog = Programme.create(:title=>"my prog")
      prog.save!
      assert prog.is_activated?
    end
  end

  test 'programme activated automatically when current_user is nil' do
    User.with_current_user nil do
      prog = Programme.create(:title=>"my prog")
      prog.save!
      assert prog.is_activated?
    end
  end

  test 'programme not activated automatically when created by a normal user' do
    Factory(:admin) # to avoid 1st person being an admin
    User.with_current_user Factory(:person).user do
      prog = Programme.create(:title=>"my prog")
      prog.save!
      refute prog.is_activated?
    end
  end

  test "doesn't change activation flag on later save" do
    Factory(:admin) # to avoid 1st person being an admin
    prog = Factory(:programme)
    assert prog.is_activated?
    User.with_current_user Factory(:person).user do
      prog.title="fish"
      disable_authorization_checks{prog.save!}
      assert prog.is_activated?
    end
  end

  test "activated scope" do
    activated_prog = Factory(:programme)
    not_activated_prog = Factory(:programme)
    not_activated_prog.is_activated=false
    disable_authorization_checks{not_activated_prog.save!}

    assert_includes Programme.activated,activated_prog
    refute_includes Programme.activated,not_activated_prog
  end

  test "activate" do
    prog = Factory(:programme)
    prog.is_activated=false
    disable_authorization_checks{prog.save!}

    #no current user
    prog.activate
    refute prog.is_activated?

    #normal user
    User.current_user=Factory(:person).user
    prog.activate
    refute prog.is_activated?

    #admin
    User.current_user=Factory(:admin).user
    prog.activate
    assert prog.is_activated?
  end

end