module ApiIntegrationTestHelper
  include AuthenticatedTestHelper

  def admin_login
    admin = Factory.create(:admin)
    @current_person = admin
    @current_user = admin.user
    post '/session', login: admin.user.login, password: ('0' * User::MIN_PASSWORD_LENGTH)

  end

  def user_login(person)
    @current_person = person
    @current_user = person.user
    @current_user.password = 'blah'
    User.current_user = Factory(:user, login: 'test')
    post '/session', login: person.user.login, password: ('0' * User::MIN_PASSWORD_LENGTH)
  end

  def load_mm_objects(clz)
    @json_mm = {}
    ['min', 'max'].each do |m|
      json_mm_file = File.join(Rails.root, 'test', 'fixtures', 'files', 'json', 'content_compare', "#{m}_#{clz}.json")
      @json_mm["#{m}"] = JSON.parse(File.read(json_mm_file))
      #TO DO may need to separate that later
      @json_mm["#{m}"]["data"].delete("id")
    end
  end

  #only in max object
  def edit_relationships
    if @json_mm.blank? then
      skip
      end
    @json_mm['max']['data']['relationships'].each do |k,v|
      obj = Factory(("#{k}".singularize).to_sym)
      @json_mm['max']['data']['relationships'][k]['data'] = [].append({"id": "#{obj.id}", "type": "#{k}"})
    end
  end

  def remove_nil_values_before_update
    unless @json_mm.blank? then
      ['min', 'max'].each do |m|
      @json_mm["#{m}"]["data"]["attributes"].each do |k, v|
        @json_mm["#{m}"]["data"]["attributes"].delete k if @json_mm["#{m}"]["data"]["attributes"][k].nil?
      end
      end
      end
  end

  def check_attr_content(to_post, action)
    #check some of the content, h = the response hash after the post/patch action
    h = JSON.parse(response.body)
    h['data']['attributes'].delete("mbox_sha1sum")
    h['data']['attributes'].delete("avatar")
    h['data']['attributes'].each do |key, value|
      next if (to_post['data']['attributes'][key].nil? && action=="patch")
      if value.nil?
        assert_nil to_post['data']['attributes'][key]
      elsif value.kind_of?(Array)
        assert_equal value, to_post['data']['attributes'][key].sort!
      else
        assert_equal value, to_post['data']['attributes'][key]
      end
    end
  end

  # def check_relationships_content(m, action)
  #   @to_post['data']['relationships'].each do |key, value|
  #     assert_equal value, h['data']['relationships'][key]
  #   end
  # end ("#{m}_#{clz}").to_sym

  def test_should_delete_object
    begin
    obj = Factory(("#{@clz}").to_sym, contributor: @current_person)
    rescue NoMethodError
      obj = Factory(("#{@clz}").to_sym)
      end

    assert_difference "#{@clz.capitalize}.count", -1 do
    delete "/#{@plural_clz}/#{obj.id}.json"
    assert_response :success
    end

    get "/#{@plural_clz}/#{obj.id}.json"
    assert_response :not_found
  end

  def test_create_should_error_on_given_id
    if @json_mm.blank? then
      skip
      end
   @json_mm["min"]["data"]["id"] = "100000000"
    @json_mm["min"]["data"]["type"] = "#{@plural_clz}"
    post "/#{@plural_clz}.json", @json_mm["min"]
    assert_response :unprocessable_entity
    assert_match "A POST request is not allowed to specify an id", response.body

    end

  def test_create_should_error_on_wrong_type
    if @json_mm.blank? then
      skip
      end
      @json_mm["min"]["data"]["type"] = "wrong"
    post "/#{@plural_clz}.json", @json_mm["min"]
    assert_response :unprocessable_entity
    assert_match "The specified data:type does not match the URL's object (#{@json_mm["min"]["data"]["type"]} vs. #{@plural_clz})", response.body
  end


  def test_create_should_error_on_missing_type
    if @json_mm.blank? then
      skip
      end
    @json_mm["min"]["data"].delete("type")
    post "/#{@plural_clz}.json", @json_mm["min"]
    assert_response :unprocessable_entity
    assert_match "A POST/PUT request must specify a data:type", response.body
  end

  def test_update_should_error_on_wrong_id
    if @json_mm.blank? then
      skip
      end
      obj = Factory(("#{@clz}").to_sym)
    @json_mm["min"]["data"]["id"] = "100000000"
    @json_mm["min"]["data"]["type"] = "#{@plural_clz}"

    #wrong id = failire
    put "/#{@plural_clz}/#{obj.id}.json", @json_mm["min"]
    assert_response :unprocessable_entity
    assert_match "id specified by the PUT request does not match object-id in the JSON input", response.body

    #correct id = success
    @json_mm["min"]["data"]["id"] = obj.id
    @json_mm["min"]["data"]["attributes"]["title"] = "Updated #{@clz}"
    put "/#{@plural_clz}/#{obj.id}.json", @json_mm["min"]
    assert_response :success
  end

  def test_update_should_error_wrong_type
    if @json_mm.blank? then
      skip
      end
      obj = Factory(("#{@clz}").to_sym)
    @json_mm["min"]["data"]["type"] = "wrong"
    put "/#{@plural_clz}/#{obj.id}.json", @json_mm["min"]
    assert_response :unprocessable_entity
    assert_match "The specified data:type does not match the URL's object (#{@json_mm["min"]["data"]["type"]} vs. #{@plural_clz})", response.body
  end

  def test_update_should_error_on_missing_type
    if @json_mm.blank? then
      skip
      end
      obj = Factory(("#{@clz}").to_sym)
    @json_mm["min"]["data"].delete("type")
    put "/#{@plural_clz}/#{obj.id}.json", @json_mm["min"]
    assert_response :unprocessable_entity
    assert_match "A POST/PUT request must specify a data:type", response.body
  end

end
