require 'grouped_pagination'

class Assay < ActiveRecord::Base    
  
  belongs_to :assay_type
  belongs_to :technology_type
  belongs_to :culture_growth_type
  belongs_to :study
  belongs_to :organism
  belongs_to :owner, :class_name=>"Person"
  belongs_to :assay_class

  has_many :assay_assets, :dependent => :destroy

  has_one :investigation,:through=>:study    

  has_many :assets,:through=>:assay_assets

  validates_presence_of :title
  validates_uniqueness_of :title

  validates_presence_of :assay_type
  validates_presence_of :technology_type
  validates_presence_of :study, :message=>" must be selected"
  validates_presence_of :owner
  validates_presence_of :assay_class

  has_many :favourites, 
           :as => :resource, 
           :dependent => :destroy
          

  acts_as_solr(:fields=>[:description,:title],:include=>[:assay_type,:technology_type,:organism]) if SOLR_ENABLED
  
  before_save :update_first_letter
  
  grouped_pagination
  
  def short_description
    type=assay_type.nil? ? "No type" : assay_type.title
   
    "#{title} (#{type})"
  end

  def project
    investigation.nil? ? nil : investigation.project
  end

  def can_edit? user
    project.nil? || user.person.projects.include?(project)
  end

  def can_delete? user
    can_edit?(user) && data_files.empty? && sops.empty?
  end

  def sops
    assay_assets.sops.collect{|s| s.versioned_resource}
  end
  
  def models
    assay_assets.models.collect{|m| m.versioned_resource}
  end

  #returns true if this is a modelling class of assay
  def is_modelling?
    return !assay_class.nil? && assay_class.key=="MODEL"
  end

  #returns true if this is an experimental class of assay
  def is_experimental?
    return !assay_class.nil? && assay_class.key=="EXP"
  end

  def data_files
    list = []
    assay_assets.data_files.each do |df|
      v = df.versioned_resource
      v.class_eval("attr_accessor :relationship_type")
      v.relationship_type = df.relationship_type
      list << v
    end
    list
  end
  
  def update_first_letter
    self.first_letter = strip_first_letter(title)
  end
  
  #Relate an asset to this assay with a specific relationship type
  def relate(asset, relationship_type)
    assay_asset = AssayAsset.new()
    assay_asset.assay = self
    assay_asset.asset = asset
    assay_asset.relationship_type = relationship_type      
    assay_asset.save
  end
  
end
