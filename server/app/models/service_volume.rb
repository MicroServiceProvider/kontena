class ServiceVolume
  include Mongoid::Document

  embedded_in :grid_service

  field :bind_mount, type: String # optional host bind mount
  field :path, type: String # mount path in the container
  field :flags, type: String # optional flags

  belongs_to :volume # optional

  def to_s
    elements = []
    if self.volume
      elements << self.volume.name
    elsif self.bind_mount
      elements << self.bind_mount
    end
    elements << self.path
    elements << self.flags if self.flags && !self.flags.empty?
    elements.join(':')
  end

end
