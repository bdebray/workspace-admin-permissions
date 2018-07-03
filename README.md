# Agile Central: Workspace Admin Permissions Exporte

This script will retrieve a list of all Workspace Administrators and export to a csv file. The list retrieved will be based on the user permissions for the provided username/password or API Key. This is best run as a subscription administrator in order to retrieve permissions for all workspaces in a subscription.

## Getting Started

### Prerequisites

Ensure ruby is installed. The script requires the following gems:

* [json](https://rubygems.org/gems/json)
* [rally_api](https://rubygems.org/gems/rally_api)

### Installing & Running

1. Download or clone this repository
2. Update the config.json file:
   - Specify a username and password or an API Key (Read-Only is sufficient)
   - Update the default filename to a new one, if desired
3. Open terminal/console, navigate to the downloaded/cloned directory and run `ruby workspace_admins.rb config.json`
