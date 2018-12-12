module Seek
  module EnabledFeaturesFilter
    FEATURES = %i[assays biosamples documentation events models
                  nels openbis organisms programmes publications samples].freeze

    def feature_enabled?(feature)
      feature = feature.to_s
      if Seek::Config.send("#{feature}_enabled")
        true
      else
        respond_to do |format|
          format.html do
            flash[:error] = "#{feature.capitalize} are disabled"
            redirect_to main_app.root_path
          end
          format.xml { render text: '<error>' + "#{feature.capitalize} are disabled" + '</error>', status: :unprocessable_entity }
          format.json do
            render json: { "title": "#{feature.capitalize} are disabled" }, status: :unprocessable_entity
          end
        end

        false
      end
    end

    FEATURES.each do |feature|
      define_method("#{feature}_enabled?") do
        feature_enabled? feature
      end
    end
  end
end
