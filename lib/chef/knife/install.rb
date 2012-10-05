
require 'chef/knife'

class Chef
  class Knife
    class Install  < Chef::Knife

      attr_reader :version
      attr_accessor :cookbook_name

      deps do
        require 'chef/cookbook_version'
      end

      banner "knife install   COOKBOOK [VERSION] (options)"

      option :latest,
       :short => "-N",
       :long => "--latest",
       :description => "The version of the cookbook to download",
       :boolean => true

      option :download_directory,
       :short => "-d DOWNLOAD_DIRECTORY",
       :long => "--dir DOWNLOAD_DIRECTORY",
       :description => "The directory to download the cookbook into",
       :default => Dir.pwd

      option :force,
       :short => "-f",
       :long => "--force",
       :description => "Force download over the download directory if it exists"

      def run
        @cookbook_name, @version = @name_args

        if @cookbook_name.nil?
          show_usage
          ui.fatal("You must specify a cookbook name")
          exit 1
        elsif @version.nil?
          @version = determine_version
        end

        ui.info("Downloading #{@cookbook_name} cookbook version #{@version}")

        cookbook = rest.get_rest("cookbooks/#{@cookbook_name}/#{@version}")
        manifest = cookbook.manifest

        basedir = File.join(config[:download_directory], "#{@cookbook_name}-#{cookbook.version}")
        if File.exists?(basedir)
          if config[:force]
            Chef::Log.debug("Deleting #{basedir}")
            FileUtils.rm_rf(basedir)
          else
            ui.fatal("Directory #{basedir} exists, use --force to overwrite")
            exit
          end
        end

        Chef::CookbookVersion::COOKBOOK_SEGMENTS.each do |segment|
          next unless manifest.has_key?(segment)
          ui.info("Downloading #{segment}")
          manifest[segment].each do |segment_file|
            dest = File.join(basedir, segment_file['path'].gsub('/', File::SEPARATOR))
            Chef::Log.debug("Downloading #{segment_file['path']} to #{dest}")
            FileUtils.mkdir_p(File.dirname(dest))
            rest.sign_on_redirect = false
            tempfile = rest.get_rest(segment_file['url'], true)
            FileUtils.mv(tempfile.path, dest)
          end
        end
        ui.info("Cookbook downloaded to #{basedir}")
      end

      def determine_version
        if available_versions.size == 1
          @version = available_versions.first
        elsif config[:latest]
          @version = available_versions.map { |v| Chef::Version.new(v) }.sort.last
        else
          ask_which_version
        end
      end

      def available_versions
        @available_versions ||= begin
          versions = Chef::CookbookVersion.available_versions(@cookbook_name).map do |version|
            Chef::Version.new(version)
          end
          versions.sort!
          versions
        end
        @available_versions
      end

      def ask_which_version
        question = "Which version do you want to download?\n"
        valid_responses = {}
        available_versions.each_with_index do |version, index|
          valid_responses[(index + 1).to_s] = version
          question << "#{index + 1}. #{@cookbook_name} #{version}\n"
        end
        question += "\n"
        response = ask_question(question).strip

        unless @version = valid_responses[response]
          ui.error("'#{response}' is not a valid value.")
          exit(1)
        end
        @version
      end

    end
  end
end
