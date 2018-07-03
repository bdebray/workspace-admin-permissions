require 'rally_api'
require 'json'
require 'csv'
require 'logger'

class RallyWorkspaceAdmins

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
		@logger 			= Logger.new('./workspace_permissions.log')
		@logger.progname 	= "WorkspaceAdmins"
		@logger.level 		= Logger::DEBUG # UNKNOWN | FATAL | ERROR | WARN | INFO | DEBUG
	end

    def find_workspace_admins
        query = RallyAPI::RallyQuery.new()
        query.type = "workspacepermission"
        query.fetch = "Name,Workspace,User,Role"
        query.query_string = "(((Role = \"Admin\") AND (Workspace.State = \"Open\")) AND (User.Disabled = \"false\"))"
        
        return @rally.find(query)
    end

	def find_user(objectuuid)

        user = User_Hash[objectuuid]
        
        if (user != nil)
            return user
        end
        
		test_query = RallyAPI::RallyQuery.new()
		test_query.type = "user"
		test_query.fetch = "Name,ObjectID,UserName,EmailAddress,DisplayName,FirstName,LastName"
		test_query.page_size = 20       #optional - default is 200
		test_query.limit = 1000          #optional - default is 99999
		test_query.project_scope_up = false
		test_query.project_scope_down = true
		test_query.order = "Name Asc"
		test_query.query_string = "(ObjectUUID = \"#{objectuuid}\")"

		results = @rally.find(test_query)
        user = results.first

        User_Hash[objectuuid] = user

        return user
	end

	def run
		start_time = Time.now
        
        permissions = find_workspace_admins
        
        sorted_permissions = permissions.sort_by{ |p| [p["Workspace"].Name, p["User"]._refObjectName]}
        distinct_workspaces = permissions.uniq{|p| p["Workspace"].Name}
        
        print "Found #{permissions.length} workspace permissions for #{distinct_workspaces.length} workspaces\n"
		@logger.info "Found #{permissions.length} workspace permissions for #{distinct_workspaces.length} workspaces\n"
        
        CSV.open(@csv_file_name, "wb") do |csv|
			csv << ["WorkspaceName","DisplayName","LastName","FirstName","EmailAddress"]
        
        sorted_permissions.each { |permission| 
            user = find_user(permission["User"]._refObjectUUID)

            if (user != nil)
				if (user["DisplayName"] != nil)
					userdisplay = user["DisplayName"]
				else
					userdisplay = user["EmailAddress"]
				end
				else
					userdisplay = "(None)"
				end

			emaildisplay = user != nil ? user["EmailAddress"] : "(None)" 

            csv << [permission["Workspace"],userdisplay,user["LastName"],user["FirstName"],emaildisplay]
            }
        end
        print "Finished: elapsed time #{'%.1f' % ((Time.now - start_time)/60)} minutes."
		@logger.info "Finished: elapsed time #{'%.1f' % ((Time.now - start_time)/60)} minutes."
	end
end

if (!ARGV[0])
	print "Usage: ruby workspace_admins.rb config_file_name.json\n"
	@logger.info "Usage: ruby workspace_admins.rb config_file_name.json\n"
else
	rtr = RallyWorkspaceAdmins.new ARGV[0]
	rtr.run
end