require 'rubygems'
require 'chef/knife'
require 'chef/node'
require 'chef/application'
require 'chef/client'
require 'chef/config'
require 'chef/daemon'
require 'chef/log'
require 'chef/rest'
require 'chef/handler/error_report'
require 'time'
class Chef
  class Knife
    class Install  < Chef::Knife

      attr_reader :version
      attr_accessor :cookbook_name

      deps do
        require 'chef/cookbook_version'
      end

      banner 'knife install [PATTERN,[PATTERN]]  (option)'
      

      option :latest,
       :short => '-N',
       :long => '--latest',
       :description => 'The version of the cookbook to download',
       :boolean => true

      option :download_directory,
       :short => '-d DOWNLOAD_DIRECTORY',
       :long => '--dir DOWNLOAD_DIRECTORY',
       :description => 'The directory to download the cookbook into',
       :default => Dir.pwd

      option :force,
       :short => '-f',
       :long => '--force',
       :description => 'Force download over the download directory if it exists'
     

      def run
	@runlist_as_string = name_args[1.. -1]

    	if ! @runlist_as_string.empty?
      		ui.fatal "You must specify  a   run List "
      		show_usage
      		exit 1
    	end
	@node =  create_ephemeral_node
    	@run_list_expansion = @node.expand!('server')
    	@expanded_run_list_with_versions = @run_list_expansion.recipes.with_version_constraints_strings
	pp @node
 	pp  @expanded_run_list_with_versions   
	@cookbook_hash ||= rest.get_rest("nodes/#{@node.couchdb}/cookbooks").each { |cb| pp cb[0] => cb[1].version }
	pp  @cookbook_hash
	@cookbook_hash.each  {   |cookbook_name ,  cookbook_version  | 
			 download_cookbook( cookbook_name ,  cookbook_version ) 
		}
	end


  	def create_ephemeral_node
		@node_name  =  'ephemeral'+ Time.now.to_i.to_s
    		@node ||= Chef::Node.new(@node_name)
		@node
  	end


 	def do_rest_call
        	begin
          	@children ||= rest.get_rest(api_path).keys.map do |key|
            	_make_child_entry("#{key}.json", true)
          	end
        	rescue Net::HTTPServerException
          		if $!.response.code == "404"
            			raise NotFoundError.new($!), "#{path_for_printing} not found"
          		else
            			raise
          		end
        	end
      end




      def create_child(name, file_contents)
        json = Chef::JSONCompat.from_json(file_contents).to_hash
        base_name = name[0,name.length-5]
        if json.include?('name') && json['name'] != base_name
          raise "Name in #{path_for_printing}/#{name} must be '#{base_name}' (is '#{json['name']}')"
        elsif json.include?('id') && json['id'] != base_name
          raise "Name in #{path_for_printing}/#{name} must be '#{base_name}' (is '#{json['id']}')"
        end
        rest.post_rest(api_path, json)
        _make_child_entry(name, true)
      end

      def environment
        parent.environment
      end


      def _make_child_entry(name, exists = nil)
        RestListEntry.new(name, self, exists)
      end






  	def print_initial_state
    		ui.msg "Intitial Attribute State:"
    		@previous_state = current_attr_state
    		ui.output @previous_state
  	end




     def  download_cookbook(cookbook_name ,version) 
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

