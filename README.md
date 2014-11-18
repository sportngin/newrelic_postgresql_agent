## PostgreSQL extension for the New Relic platform

This is a fork of the [PostgreSQL New Relic Plugin](http://newrelic.com/plugins/enterprisedb-corporation/30) by [EnterpriseDB](http://www.enterprisedb.com/). The purpose of this fork is to make it useable by [newrelic-ng](https://github.com/chr4-cookbooks/newrelic-ng).

Follow the instructions below to use the agent:

1. Run `bundle install` to install required gems.

2. Copy `config/postgresql_config.yml.in` to `config/postgresql_config.yml`.

3. Edit `config/postgresql_config.yml` and replace "YOUR_LICENSE_KEY_HERE" with
   your New Relic licence key.

4. Edit the `config/postgresql_config.yml` file and add the details of the 
   PostgreSQL instance(s) you wish to monitor.

5. If required add the library path of your PostgreSQL to the LD_LIBRARY_PATH 
   variable so the agent can find libpq.

6. Set the password(s) of the PostgreSQL instance(s) you wish to monitor in 
   either ~/.pgpass file or the  PGPASSWORD environment variable.

7. Execute `ruby postgresql_agent.rb`

8. Go back to the Extensions list on the New Relic website, and after a brief 
   period you should see the extension listed.
