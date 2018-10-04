class ProjectStatsController < StatsController
  before_filter :find_project
  before_filter :member_of_this_project
  skip_before_filter :is_user_admin_auth

  private

  def stats
    Seek::Stats::DashboardStats.new(@project)
  end

  def find_project
    name = t('project')
    @project = Project.find_by_id(params[:project_id])
    if @project.nil?
      respond_to do |format|
        flash[:error] = "The #{name.humanize} does not exist!"
        format.html { redirect_to project_path(@project) }
      end
    end
  end

  def member_of_this_project
    unless @project.has_member?(current_user)
      flash[:error] = "You are not a member of this #{t('project')}, so cannot access this page."
      redirect_to project_path(@project)
      false
    end
  end
end
