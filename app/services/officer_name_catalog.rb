class OfficerNameCatalog
  class << self
    def first_names
      data["first_names"]
    end

    def last_names
      data["last_names"]
    end

    private

    def data
      @data ||= YAML.load_file(Rails.root.join("config/officer_names.yml"))
    end
  end
end
