#!/usr/bin/env ruby
##############################################################################
#
# PostgreSQL extension for New Relic
#
# Copyright 2012 - 2013, EnterpriseDB Corporation
#
# This software is released under the PostgreSQL Licence:
#     http://opensource.org/licenses/PostgreSQL
#
##############################################################################

require "rubygems"
require "bundler/setup"
require "newrelic_plugin"
require "pg"

# PostgreSQL plugin code
# This defines the module of the required agent
module PostgreSqlAgent

	# Agent class definition
	class Agent < NewRelic::Plugin::Agent::Base
		agent_guid "com.enterprisedb.newrelic.postgresql"
		agent_config_options :description,:connection_str,:get_db_stat,:get_db_size,:get_tblspc_size,:get_bg_writer_stat,:get_lock_info_stat
		agent_human_labels("PostgreSQL") { "#{description}" }
		agent_version '1.0.1'

		# this function is required to define a set of processors for the
		# metrics that we are going to send to the server
		def setup_metrics
			@num_backends=NewRelic::Processor::EpochCounter.new
			@idle_backends=NewRelic::Processor::EpochCounter.new
			@xact_commits=NewRelic::Processor::EpochCounter.new
			@xact_rollbacks=NewRelic::Processor::EpochCounter.new
			@blks_hits=NewRelic::Processor::EpochCounter.new
			@blks_read=NewRelic::Processor::EpochCounter.new
			@tup_returned=NewRelic::Processor::EpochCounter.new
			@tup_fetched=NewRelic::Processor::EpochCounter.new
			@tup_inserted=NewRelic::Processor::EpochCounter.new
			@tup_updated=NewRelic::Processor::EpochCounter.new
			@tup_deleted=NewRelic::Processor::EpochCounter.new
			@checkpoints_timed=NewRelic::Processor::EpochCounter.new
			@checkpoints_req=NewRelic::Processor::EpochCounter.new
			@buffers_checkpoint=NewRelic::Processor::EpochCounter.new
			@buffers_clean=NewRelic::Processor::EpochCounter.new
			@buffers_backend=NewRelic::Processor::EpochCounter.new
			@buffers_alloc=NewRelic::Processor::EpochCounter.new
			@maxwritten_clean=NewRelic::Processor::EpochCounter.new
		end

		# this is the main method that will be called at an interval of
		# 1 minute and run. This will read all the metrics an report them
		# to the new relic server
		def poll_cycle
			setup_connection
			if @db == nil
				return
			end

			info_stat=server_info_stats
			if info_stat != nil
				report_metric "ServerInfo/Shared Buffers","MB",info_stat["shared_buffers_mb"]
				report_metric "ServerInfo/Temp Buffers","MB",info_stat["temp_buffers_mb"]
				report_metric "ServerInfo/Effective Cache Size","MB",info_stat["effective_cache_size_mb"]
				report_metric "ServerInfo/Segment Size","MB",info_stat["segment_size_mb"]
				report_metric "ServerInfo/WAL Segment Size","MB",info_stat["wal_segment_size_mb"]
				report_metric "ServerInfo/WAL Buffers Size","MB",info_stat["wal_buffers_mb"]
				report_metric "ServerInfo/Working Memory","MB",info_stat["work_mem_mb"]
			end

			db_stat=server_database_stats
			if db_stat != nil
				if @get_db_stat == true
					report_metric "DbStat/Backends Total","backends/sec",@num_backends.process(db_stat["num_backends"])
					report_metric "DbStat/Backends Idle","backends/sec",@idle_backends.process(db_stat["idle_backends"])
					report_metric "DbStat/Transactions Committed","txns/sec",@xact_commits.process(db_stat["xact_commit"])
					report_metric "DbStat/Transactions Aborted",  "txns/sec",@xact_rollbacks.process(db_stat["xact_rollback"])
					report_metric "DbStat/Blocks Hit","blocks/sec",@blks_hits.process(db_stat["blks_hit"])
					report_metric "DbStat/Blocks Read","blocks/sec",@blks_read.process(db_stat["blks_read"])
					report_metric "DbStat/Tuples Fetched","tuples/sec",@tup_fetched.process(db_stat["tup_fetched"])
					report_metric "DbStat/Tuples Returned","tuples/sec",@tup_returned.process(db_stat["tup_returned"])
					report_metric "DbStat/Tuples Inserted","tuples/sec",@tup_inserted.process(db_stat["tup_inserted"])
					report_metric "DbStat/Tuples Updated","tuples/sec",@tup_updated.process(db_stat["tup_updated"])
					report_metric "DbStat/Tuples Deleted","tuples/sec",@tup_deleted.process(db_stat["tup_deleted"])
				end
				# put one stat of ServerInfo here
				report_metric "ServerInfo/Blocks Hit Ratio",  "ratio" ,   db_stat["hit_ratio"]
			end

			if @get_db_size == true
				dbsize_stat=server_dbsize_stats
				if dbsize_stat != nil
					dbsize_stat.each do |val|
						report_metric "Database/Size/#{val["dbname"]}","MB",val["dbsize_mb"]
					end
				end
			end

			if @get_tblspc_size == true
				tblspcsize_stat=server_tblspcsize_stats
				if tblspcsize_stat != nil
					tblspcsize_stat.each do |val|
						report_metric "Tablespace/Size/#{val["tblspcname"]}","MB",val["tblspcsize_mb"]
					end
				end
			end

			if @get_bg_writer_stat == true
				bgwriter_stat=server_bgwriter_stats
				if bgwriter_stat != nil
					report_metric "BgWrStat/Checkpoints Timed","checkpoints/sec",@checkpoints_timed.process(bgwriter_stat["checkpoints_timed"])
					report_metric "BgWrStat/Checkpoints Untimed","checkpoints/sec",@checkpoints_req.process(bgwriter_stat["checkpoints_req"])
					report_metric "BgWrStat/Buffers Written Checkpoint","buffers/sec",@buffers_checkpoint.process(bgwriter_stat["buffers_checkpoint"])
					report_metric "BgWrStat/Buffers Written Cleaning Scan","buffers/sec",@buffers_clean.process(bgwriter_stat["buffers_clean"])
					report_metric "BgWrStat/Cleaning Scans Writing Maximum Buffer Count","buffers/sec",@maxwritten_clean.process(bgwriter_stat["maxwritten_clean"])
					report_metric "BgWrStat/Buffers Written Backends","buffers/sec",@buffers_backend.process(bgwriter_stat["buffers_backend"])
					report_metric "BgWrStat/Buffers Allocated","bufffers/sec",@buffers_alloc.process(bgwriter_stat["buffers_alloc"])
				end
			end

			lockinfo_stat=server_lockinfo_stats
			if lockinfo_stat != nil
				if @get_lock_info_stat == true
					report_metric "LockModeGranted/Access Share Lock", "locks",lockinfo_stat["access_share_lock_granted"]
					report_metric "LockModeGranted/Row Share Lock", "locks",lockinfo_stat["row_share_lock_granted"]
					report_metric "LockModeGranted/Row Exclusive Lock", "locks",lockinfo_stat["row_exclusive_lock_granted"]
					report_metric "LockModeGranted/Share Update Exclusive Lock","locks",lockinfo_stat["share_update_exclusive_lock_granted"]
					report_metric "LockModeGranted/Share Lock", "locks",lockinfo_stat["share_lock_granted"]
					report_metric "LockModeGranted/Share Row Exclusive Lock", "locks",lockinfo_stat["share_row_exclusive_lock_granted"]
					report_metric "LockModeGranted/Exclusive Lock", "locks",lockinfo_stat["exclusive_lock_granted"]
					report_metric "LockModeGranted/Access Exclusive Lock", "locks",lockinfo_stat["access_exclusive_lock_granted"]
					report_metric "LockModeWaiting/Access Share Lock", "locks",lockinfo_stat["access_share_lock_waiting"]
					report_metric "LockModeWaiting/Row Share Lock", "locks",lockinfo_stat["row_share_lock_waiting"]
					report_metric "LockModeWaiting/Row Exclusive Lock", "locks",lockinfo_stat["row_exclusive_lock_waiting"]
					report_metric "LockModeWaiting/Share Update Exclusive Lock","locks",lockinfo_stat["share_update_exclusive_lock_waiting"]
					report_metric "LockModeWaiting/Share Lock", "locks",lockinfo_stat["share_lock_waiting"]
					report_metric "LockModeWaiting/Share Row Exclusive Lock", "locks",lockinfo_stat["share_row_exclusive_lock_waiting"]
					report_metric "LockModeWaiting/Exclusive Lock", "locks",lockinfo_stat["exclusive_lock_waiting"]
					report_metric "LockModeWaiting/Access Exclusive Lock", "locks",lockinfo_stat["access_exclusive_lock_waiting"]
					report_metric "LockTypeGranted/Relation", "locks",lockinfo_stat["relation_type_granted"]
					report_metric "LockTypeGranted/Extend", "locks",lockinfo_stat["extend_type_granted"]
					report_metric "LockTypeGranted/Page", "locks",lockinfo_stat["page_type_granted"]
					report_metric "LockTypeGranted/Tuple", "locks",lockinfo_stat["tuple_type_granted"]
					report_metric "LockTypeGranted/Transactionid", "locks",lockinfo_stat["transactionid_type_granted"]
					report_metric "LockTypeGranted/Virtualxid", "locks",lockinfo_stat["virtualxid_type_granted"]
					report_metric "LockTypeGranted/Object", "locks",lockinfo_stat["object_type_granted"]
					report_metric "LockTypeGranted/Advisory", "locks",lockinfo_stat["advisory_type_granted"]
					report_metric "LockTypeWaiting/Relation", "locks",lockinfo_stat["relation_type_waiting"]
					report_metric "LockTypeWaiting/Extend", "locks",lockinfo_stat["extend_type_waiting"]
					report_metric "LockTypeWaiting/Page", "locks",lockinfo_stat["page_type_waiting"]
					report_metric "LockTypeWaiting/Tuple", "locks",lockinfo_stat["tuple_type_waiting"]
					report_metric "LockTypeWaiting/Transactionid", "locks",lockinfo_stat["transactionid_type_waiting"]
					report_metric "LockTypeWaiting/Virtualxid", "locks",lockinfo_stat["virtualxid_type_waiting"]
					report_metric "LockTypeWaiting/Object", "locks",lockinfo_stat["object_type_waiting"]
					report_metric "LockTypeWaiting/Advisory", "locks",lockinfo_stat["advisory_type_waiting"]
				end
				# put one stat of ServerInfo here
				report_metric "ServerInfo/Total Locks","locks",lockinfo_stat["total_locks"]
			end

			@db.finish
			@db = nil
		end

		private

		# getter function for description variable
		def description
			@description || "PostgreSQL Plugin"
		end

		# getter function for connection string
		def connection_str
			@connection_str || nil
		end

		# getter function for get_db_stat param
		def get_db_stat
			@get_db_stat || false
		end

		# getter function for get_db_size param
		def get_db_size
			@get_db_size || false
		end

		# getter function for get_tblspc_size param
		def get_tblspc_size
			@get_tblspc_size || false
		end

		# getter function for get_bg_writer_stat param
		def get_bg_writer_stat
			@get_bg_writer_stat || false
		end

		# getter function for get_lock_info_stat param
		def get_lock_info_stat
			@get_lock_info_stat || false
		end

		# get server version for the server being monitored
		def get_server_version
			begin
				res = @db.exec %Q{ SELECT
					pg_catalog.version() as version_string
				}

				super_ver = 20000
				if (res[0]['version_string'].split(' ')[0] == 'PostgreSQL')
					super_ver = 10000
				end
				ver = super_ver + Integer(res[0]['version_string'].split(' ')[1].split('.')[0])*100 +
						Integer(res[0]['version_string'].split(' ')[1].split('.')[1]);
				return ver

			rescue PG::Error => err
				$stderr.puts "Server version query failed: %s" % [ err.message ]
				@db = nil
			end
		end

		# setup a connection to the server
		def setup_connection
			begin
				@db   = PG.connect(@connection_str)
				@version = get_server_version

			rescue PG::Error => err
				$stderr.puts "Connection failed: %s" % [ err.message ]
				@db = nil
			end
		end

		# collect the server information statistics
		def server_info_stats
			begin
				if @version == 10903 or @version == 10902 or @version == 10901  or @version == 10900  or @version == 10804
					res = @db.exec %Q{
						WITH server_block_size AS (
						        SELECT setting::decimal AS block_size FROM pg_settings WHERE name = 'block_size'
						)
						SELECT
						        ((SELECT setting FROM pg_settings WHERE name = 'shared_buffers')::decimal * block_size / (1024 * 1024))::decimal(10,4) AS shared_buffers_mb,
						        ((SELECT setting FROM pg_settings WHERE name = 'temp_buffers')::decimal  * block_size / (1024 * 1024))::decimal(10,4) AS temp_buffers_mb,
						        ((SELECT setting FROM pg_settings WHERE name = 'effective_cache_size')::decimal * block_size / (1024 * 1024))::decimal(10,4) AS effective_cache_size_mb,
						        ((SELECT setting FROM pg_settings WHERE name = 'segment_size')::decimal * block_size / (1024 * 1024))::decimal(10,4) AS segment_size_mb,
						        ((SELECT setting FROM pg_settings WHERE name = 'wal_segment_size')::decimal * block_size / (1024 * 1024))::decimal(10,4) AS wal_segment_size_mb,
						        ((SELECT setting FROM pg_settings WHERE name = 'wal_buffers')::decimal * block_size / (1024 * 1024))::decimal(10,4) AS wal_buffers_mb,
						        ((SELECT setting FROM pg_settings WHERE name = 'work_mem')::decimal / 1024)::decimal(10,4) AS work_mem_mb
						FROM
						        server_block_size
					}
				else
					res = @db.exec %Q{
						SELECT
							((select setting from pg_settings where name = 'block_size')::decimal * (select setting from pg_settings where name = 'shared_buffers')::decimal / (1024 * 1024))::decimal(10,4) AS shared_buffers_mb,
							((select setting from pg_settings where name = 'block_size')::decimal * (select setting from pg_settings where name = 'temp_buffers')::decimal / (1024 * 1024))::decimal(10,4) AS temp_buffers_mb,
							((select setting from pg_settings where name = 'block_size')::decimal * (select setting from pg_settings where name = 'effective_cache_size')::decimal / (1024 * 1024))::decimal(10,4) AS effective_cache_size_mb,
							((select setting from pg_settings where name = 'block_size')::decimal * (select setting from pg_settings where name = 'segment_size')::decimal / (1024 * 1024))::decimal(10,4) AS segment_size_mb,
							((select setting from pg_settings where name = 'block_size')::decimal * (select setting from pg_settings where name = 'wal_segment_size')::decimal / (1024 * 1024))::decimal(10,4) AS wal_segment_size_mb,
							((select setting from pg_settings where name = 'block_size')::decimal * (select setting from pg_settings where name = 'wal_buffers')::decimal / (1024 * 1024))::decimal(10,4) AS wal_buffers_mb,
							((SELECT setting FROM pg_settings WHERE name = 'work_mem')::decimal / 1024)::decimal(10,4) AS work_mem_mb
					}
				end
			        return res[0]

			rescue PG::Error => err
				$stderr.puts "Server info stat error: %s" % [ err.message ]
				return nil
			end
	    	end

		# collect the server's database statistics
		def server_database_stats
			begin
				if @version == 10903 or @version == 10902
					res = @db.exec %Q{
						SELECT
							SUM(d1.numbackends) AS num_backends,
							SUM((SELECT COALESCE(count(query)::bigint, 0::bigint) FROM pg_catalog.pg_stat_activity WHERE datname = d1.datname AND query = '<IDLE>')) AS idle_backends,
							SUM(d1.xact_commit) AS xact_commit,
							SUM(d1.xact_rollback) AS xact_rollback,
							SUM(d1.blks_hit) AS blks_hit,
							SUM(d1.blks_read) AS blks_read,
							SUM(d1.tup_returned) AS tup_returned,
							SUM(d1.tup_fetched) AS tup_fetched,
							SUM(d1.tup_inserted) AS tup_inserted,
							SUM(d1.tup_updated) AS tup_updated,
							SUM(d1.tup_deleted) AS tup_deleted,
							(CASE WHEN SUM(d1.blks_hit) + SUM(d1.blks_read) = 0 THEN 0 ELSE SUM(blks_hit) * 100 / (SUM(blks_hit) + SUM(blks_read)) END)::numeric(30,2) AS hit_ratio
						FROM
							pg_catalog.pg_stat_database d1
					}
				else
					res = @db.exec %Q{
						SELECT
							SUM(d1.numbackends) AS num_backends,
							SUM((SELECT COALESCE(count(current_query)::bigint, 0::bigint) FROM pg_catalog.pg_stat_activity WHERE datname = d1.datname AND current_query = '<IDLE>')) AS idle_backends,
							SUM(d1.xact_commit) AS xact_commit,
							SUM(d1.xact_rollback) AS xact_rollback,
							SUM(d1.blks_hit) AS blks_hit,
							SUM(d1.blks_read) AS blks_read,
							SUM(d1.tup_returned) AS tup_returned,
							SUM(d1.tup_fetched) AS tup_fetched,
							SUM(d1.tup_inserted) AS tup_inserted,
							SUM(d1.tup_updated) AS tup_updated,
							SUM(d1.tup_deleted) AS tup_deleted,
							(CASE WHEN SUM(d1.blks_hit) + SUM(d1.blks_read) = 0 THEN 0 ELSE SUM(blks_hit) * 100 / (SUM(blks_hit) + SUM(blks_read)) END)::numeric(30,2) AS hit_ratio
						FROM
							pg_catalog.pg_stat_database d1
					}
				end
				return res[0]

			rescue PG::Error => err
				$stderr.puts "Server database stat error: %s" % [ err.message ]
				return nil
			end
		end

		# collect the database size statistics
		def server_dbsize_stats
			begin
				res = @db.exec %Q{
					SELECT datname AS dbname, pg_database_size(a.oid) / 1048576 AS dbsize_mb FROM pg_catalog.pg_database a, pg_catalog.pg_tablespace b WHERE a.dattablespace = b.oid
				}
				return res

			rescue PG::Error => err
				$stderr.puts "Server dbsize stat error: %s" % [ err.message ]
				return nil
			end
		end

		# collect the tablespace size statistics
		def server_tblspcsize_stats
			begin
				res = @db.exec %Q{
					SELECT spcname AS tblspcname, pg_catalog.pg_tablespace_size(oid) / 1048576 AS tblspcsize_mb FROM pg_catalog.pg_tablespace
				}
				return res

			rescue PG::Error => err
				$stderr.puts "Server tblspcsize stat error: %s" % [ err.message ]
				return nil
			end
		end

		# collect the bgwriter statistics
		def server_bgwriter_stats
			begin
				res = @db.exec %Q{
					SELECT checkpoints_timed, checkpoints_req, buffers_clean, buffers_checkpoint, maxwritten_clean, buffers_backend, buffers_alloc FROM pg_catalog.pg_stat_bgwriter
				}
				return res[0]

			rescue PG::Error => err
				$stderr.puts "Server bgwriter stat error: %s" % [ err.message ]
				return nil
			end
		end

		# collect the lock info statistics
		def server_lockinfo_stats
			begin
				res = @db.exec %Q{
					SELECT
						COUNT(CASE WHEN mode = 'AccessShareLock' AND granted THEN 1 ELSE NULL END) AS access_share_lock_granted,
						COUNT(CASE WHEN mode = 'RowShareLock' AND granted THEN 1 ELSE NULL END) AS row_share_lock_granted,
						COUNT(CASE WHEN mode = 'RowExclusiveLock' AND granted THEN 1 ELSE NULL END) AS row_exclusive_lock_granted,
						COUNT(CASE WHEN mode = 'ShareUpdateExclusiveLock' AND granted THEN 1 ELSE NULL END) AS share_update_exclusive_lock_granted,
						COUNT(CASE WHEN mode = 'ShareLock' AND granted THEN 1 ELSE NULL END) AS share_lock_granted,
						COUNT(CASE WHEN mode = 'ShareRowExclusiveLock' AND granted THEN 1 ELSE NULL END) AS share_row_exclusive_lock_granted,
						COUNT(CASE WHEN mode = 'ExclusiveLock' AND granted THEN 1 ELSE NULL END) AS exclusive_lock_granted,
						COUNT(CASE WHEN mode = 'AccessExclusiveLock' AND granted THEN 1 ELSE NULL END) AS access_exclusive_lock_granted,
						COUNT(CASE WHEN mode = 'AccessShareLock' AND NOT granted THEN 1 ELSE NULL END) AS access_share_lock_waiting,
						COUNT(CASE WHEN mode = 'RowShareLock' AND NOT granted THEN 1 ELSE NULL END) AS row_share_lock_waiting,
						COUNT(CASE WHEN mode = 'RowExclusiveLock' AND NOT granted THEN 1 ELSE NULL END) AS row_exclusive_lock_waiting,
						COUNT(CASE WHEN mode = 'ShareUpdateExclusiveLock' AND NOT granted THEN 1 ELSE NULL END) AS share_update_exclusive_lock_waiting,
						COUNT(CASE WHEN mode = 'ShareLock' AND NOT granted THEN 1 ELSE NULL END) AS share_lock_waiting,
						COUNT(CASE WHEN mode = 'ShareRowExclusiveLock' AND NOT granted THEN 1 ELSE NULL END) AS share_row_exclusive_lock_waiting,
						COUNT(CASE WHEN mode = 'ExclusiveLock' AND NOT granted THEN 1 ELSE NULL END) AS exclusive_lock_waiting,
						COUNT(CASE WHEN mode = 'AccessExclusiveLock' AND NOT granted THEN 1 ELSE NULL END) AS access_exclusive_lock_waiting,
						COUNT(CASE WHEN locktype = 'relation' AND granted THEN 1 ELSE NULL END) AS relation_type_granted,
						COUNT(CASE WHEN locktype = 'extend' AND granted THEN 1 ELSE NULL END) AS extend_type_granted,
						COUNT(CASE WHEN locktype = 'page' AND granted THEN 1 ELSE NULL END) AS page_type_granted,
						COUNT(CASE WHEN locktype = 'tuple' AND granted THEN 1 ELSE NULL END) AS tuple_type_granted,
						COUNT(CASE WHEN locktype = 'transactionid' AND granted THEN 1 ELSE NULL END) AS transactionid_type_granted,
						COUNT(CASE WHEN locktype = 'virtualxid' AND granted THEN 1 ELSE NULL END) AS virtualxid_type_granted,
						COUNT(CASE WHEN locktype = 'object' AND granted THEN 1 ELSE NULL END) AS object_type_granted,
						COUNT(CASE WHEN locktype = 'advisory' AND granted THEN 1 ELSE NULL END) AS advisory_type_granted,
						COUNT(CASE WHEN locktype = 'relation' AND NOT granted THEN 1 ELSE NULL END) AS relation_type_waiting,
						COUNT(CASE WHEN locktype = 'extend' AND NOT granted THEN 1 ELSE NULL END) AS extend_type_waiting,
						COUNT(CASE WHEN locktype = 'page' AND NOT granted THEN 1 ELSE NULL END) AS page_type_waiting,
						COUNT(CASE WHEN locktype = 'tuple' AND NOT granted THEN 1 ELSE NULL END) AS tuple_type_waiting,
						COUNT(CASE WHEN locktype = 'transactionid' AND NOT granted THEN 1 ELSE NULL END) AS transactionid_type_waiting,
						COUNT(CASE WHEN locktype = 'virtualxid' AND NOT granted THEN 1 ELSE NULL END) AS virtualxid_type_waiting,
						COUNT(CASE WHEN locktype = 'object' AND NOT granted THEN 1 ELSE NULL END) AS object_type_waiting,
						COUNT(CASE WHEN locktype = 'advisory' AND NOT granted THEN 1 ELSE NULL END) AS advisory_type_waiting,
						COUNT(*) AS total_locks
					FROM
						pg_locks;
				}
				return res[0]

			rescue PG::Error => err
				$stderr.puts "Server lock infostat error: %s" % [ err.message ]
				return nil
			end
		end

	end

	# Set the configuration file
	NewRelic::Plugin::Config.config_file="config/newrelic_plugin.yml"

	# Register this agent.
	NewRelic::Plugin::Setup.install_agent :postgresql,PostgreSqlAgent

	# Launch the agent; this never returns.
	NewRelic::Plugin::Run.setup_and_run
end
