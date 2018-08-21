require 'rally_api'
require 'json'
require 'csv'
require 'logger'

class RallyWorkspaceOwners

    User_Hash = {}

	def initialize configFile

		print "Reading config file #{configFile}\n"
		print "Connecting to rally\n"
		print "Running in ", Dir.pwd,"\n"

		headers = RallyAPI::CustomHttpHeader.new({:vendor => "Vendor", :name => "Custom Name", :version => "1.0"})

		file = File.read(configFile)
		config_hash = JSON.parse(file)

		config = {:rally_url => config_hash["rally_url"]}

        if (config_hash["api_key"].length > 0)
            config[:api_key]    = config_hash["api_key"]
        else
            config[:username]   = config_hash["username"]
		  config[:password]   = config_hash["password"]
        end

        config[:headers]    = headers #from RallyAPI::CustomHttpHeader.new()

		@rally = RallyAPI::RallyRestJson.new(config)

		@csv_file_name 		= config_hash['output_filename']

		# Logger ------------------------------------------------------------
		@logger 			= Logger.new('./workspace_owners.log')
		@logger.progname 	= "WorkspaceAdmins"
		@logger.level 		= Logger::DEBUG # UNKNOWN | FATAL | ERROR | WARN | INFO | DEBUG
	end

    def find_subscription_workspaces
        query = RallyAPI::RallyQuery.new()
        query.type = "subscription"
        query.fetch = "Workspaces"
        query.page_size = 1

        return @rally.find(query).first["Workspaces"]
    end

	def find_user(objectuuid)
        if (objectuuid == nil)
            return nil
        end
        
        user = User_Hash[objectuuid]
        
        if (user != nil)
            return user
        end

		user_query = RallyAPI::RallyQuery.new()
		user_query.type = "user"
		user_query.fetch = "Name,ObjectID,UserName,EmailAddress,DisplayName,FirstName,LastName"
		user_query.page_size = 1       #optional - default is 200
		user_query.limit = 1000          #optional - default is 99999
		user_query.project_scope_up = false
		user_query.project_scope_down = true
		user_query.order = "Name Asc"
		user_query.query_string = "(ObjectUUID = \"#{objectuuid}\")"

		results = @rally.find(user_query)
        user = results.first

        User_Hash[objectuuid] = user

        return user
	end

	def run
        start_time = Time.now

        workspaces = find_subscription_workspaces.reject { |ws| ws['State'] == 'Closed' }

        print "Found #{workspaces.length} open workspaces\n"
        @logger.info "Found #{workspaces.length} open workspaces\n"

        CSV.open(@csv_file_name, "wb") do |csv|
          csv << ["WorkspaceName","Owner","LastName","FirstName","EmailAddress"]

        workspaces.each { |workspace|
            user = workspace["Owner"].nil? ? nil : find_user(workspace["Owner"]._refObjectUUID)

            userdisplay = "< NONE >"
            lastname = ""
            firstname = ""
            emaildisplay = ""
            
            if (user != nil)
                lastname = user["LastName"]
                firstname = user["FirstName"]
                emaildisplay = user["EmailAddress"]
				if (user["DisplayName"] != nil)
					userdisplay = user["DisplayName"]
				else
					userdisplay = user["EmailAddress"]
				end
            end

            csv << [workspace["Name"],userdisplay,lastname,firstname,emaildisplay]
            }
        end
        print "Finished: elapsed time #{'%.1f' % ((Time.now - start_time)/60)} minutes."
		@logger.info "Finished: elapsed time #{'%.1f' % ((Time.now - start_time)/60)} minutes."
	end
end

if (!ARGV[0])
	print "Usage: ruby workspace_owners.rb config_file_name.json\n"
	@logger.info "Usage: ruby workspace_owners.rb config_file_name.json\n"
else
	rtr = RallyWorkspaceOwners.new ARGV[0]
	rtr.run
end
