class Dashboard::SuperAdmin::Application::AnnouncementsController < SuperAdminController
  before_action :authorize_super_admin

  def index
    begin
      @application = ::Application.find(params[:application_id])
      @announcements = @application.announcements.order(created_at: :desc)

      @path_segments = request.fullpath.split("/")

      render "index"
    rescue Exception => e
      flash[:notice] = e.message
      redirect_to '/dashboard/super_admin/home'
    end
  end

  def new
    @application = ::Application.find(params[:application_id])
    render "new"
  end

  def create
    begin
      if params[:text_content] == ""
        raise Exception.new("Text content can't be empty.")
      end

      application = nil
      announcement = nil
      ActiveRecord::Base.transaction do
        # check the application id
        application = ::Application.find_by(id: params[:application_id])

        if application.nil?
          render json: {
            error: {
              message: "Application id is not found."
            }
          }, status: 404 and return
        end

        announcement = Announcement.new
        announcement.text_content = params[:text_content]
        announcement.announcement_image_url = params[:announcement_image_url]
        announcement.application_id = application.id
        announcement.save!
      end

      flash[:success] = "Success create new announcement."
      redirect_to "/dashboard/super_admin/application/#{application.id}/announcements" and return
    rescue Exception => e
      flash[:notice] = e.message
      redirect_back fallback_location: '/dashboard/super_admin/home'
    end
  end

  # get /dashboard/super_admin/application/2/announcements/4/delete
  def delete
    begin
      @announcement = ::Announcement.find_by(id: params[:id], application_id: params[:application_id])

      if @announcement.nil?
        flash[:notice] = "Announcement is not found"
        redirect_to '/dashboard/super_admin/home' and return
      end

      @announcement.destroy

      flash[:success] = "Success delete announcement."
      redirect_to "/dashboard/super_admin/application/#{params[:application_id]}/announcements"
    rescue Exception => e
      flash[:notice] = e.message
      redirect_to '/dashboard/super_admin/home'
    end
  end

  def show
    begin
      @announcement = ::Announcement.find_by(id: params[:id], application_id: params[:application_id])

      if @announcement.nil?
        flash[:notice] = "Announcement not found"
        redirect_to '/dashboard/super_admin/home' and return
      end

      render "show"
    rescue Exception => e
      flash[:notice] = e.message
      redirect_to '/dashboard/super_admin/home'
    end
  end

  def update
    begin
      announcement = nil
      ActiveRecord::Base.transaction do
        announcement = ::Announcement.find(params[:announcement_id])
        announcement.text_content = params[:text_content] if params[:text_content].present?
        announcement.announcement_image_url = params[:announcement_image_url] if params[:announcement_image_url].present?
        announcement.is_active = params[:is_active] if params[:is_active].present?
        announcement.save!
      end

      flash[:success] = "Success update announcement."
      redirect_to "/dashboard/super_admin/application/#{params[:application_id]}/announcements"
    rescue Exception => e
      flash[:notice] = e.message
      redirect_back fallback_location: '/dashboard/super_admin/home'
    end
  end

end