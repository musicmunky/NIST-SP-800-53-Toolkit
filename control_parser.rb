#!/usr/local/bin/ruby

# This script processes the 800-53-controls.xml document provided by NIST
# (https://nvd.nist.gov/static/feeds/xml/sp80053/rev4/800-53-controls.xml), and
# parses various components into a MYSQL database.

# REQUIRED GEMS:
require 'optparse'
require 'nokogiri'
require 'mysql2'
require 'sequel'


def parse_control(path)

	@cnumber = path.xpath("number").first.text
	@family_name = path.xpath("family").text
 	@family_acronym = @cnumber.split("-").first
	@title = path.xpath("title").text
	@priority = path.xpath("priority").text
	@baseline_impacts = parse_baseline_impact(path)
	@withdrawn = parse_withdrawn(path)

	puts "PROCESSING CONTROL: #{@family_acronym}, #{@cnumber}, #{@family_name}"

	@family_id = 0
	@find_family = MYSQL[:families].where(:acronym => @family_acronym).all

	if @find_family.count < 1
		puts "NEW FAMILY FOUND: #{@family_acronym}"
		@family_id = MYSQL[:families].insert(
			"name" => @family_name,
			"acronym" => @family_acronym,
			"created_at" => Time.now.strftime("%Y-%m-%d %H:%M:%S"),
			"updated_at" => Time.now.strftime("%Y-%m-%d %H:%M:%S")
		)
	else
		@family_id = @find_family.first[:id]
	end

	if @family_id > 0

		@control_id = MYSQL[:controls].insert(
			'family_id' => @family_id,
			'family_name' => @family_name,
			'number' => @cnumber,
			'title' => @title,
			'priority' => @priority,
			'is_baseline_impact_low' => @baseline_impacts['LOW'],
			'is_baseline_impact_moderate' => @baseline_impacts['MODERATE'],
			'is_baseline_impact_high' => @baseline_impacts['HIGH'],
			'is_withdrawn' => @withdrawn,
			'is_enhancement' => 0,
			"created_at" => Time.now.strftime("%Y-%m-%d %H:%M:%S"),
			"updated_at" => Time.now.strftime("%Y-%m-%d %H:%M:%S")
		)

		if path.xpath("supplemental-guidance").length > 0
			parse_supplemental_guidance(@control_id, path.xpath("supplemental-guidance"))
		end

		if path.xpath("references").length > 0
			parse_references(@control_id, path.xpath("references"))
		end

		if path.xpath("statement").length > 0
			parse_statements(@control_id, path.xpath("statement"), @number) # Because stupid NIST schema!
		end

		if path.xpath("control-enhancements").length > 0
			parse_control_enhancements(@control_id, path.xpath("control-enhancements"))
		end
	else
		puts "COULD NOT FIND FAMILY ID FOR CONTROL #{@title}"
	end

end


def parse_control_enhancements(pid, path)

 	@parent_control = MYSQL[:controls].where(:id => pid).all.first
	@family_id = @parent_control[:family_id]
	@family_name = @parent_control[:family_name]

	path.xpath("control-enhancement").each do |enhancement|

		@cnumber = enhancement.xpath("number").text
		@title = enhancement.xpath("title").text

		@baseline_impacts = parse_baseline_impact(enhancement)
		@withdrawn = parse_withdrawn(enhancement)

		@control_id = MYSQL[:controls].insert(
			'family_id' => @family_id,
			'family_name' => @family_name,
			'parent_id' => pid,
			'number' => @cnumber,
			'title' => @title,
			'priority' => "",
			'is_baseline_impact_low' => @baseline_impacts['LOW'],
			'is_baseline_impact_moderate' => @baseline_impacts['MODERATE'],
			'is_baseline_impact_high' => @baseline_impacts['HIGH'],
			'is_withdrawn' => @withdrawn,
			'is_enhancement' => 1,
			"created_at" => Time.now.strftime("%Y-%m-%d %H:%M:%S"),
			"updated_at" => Time.now.strftime("%Y-%m-%d %H:%M:%S")
		)

		if enhancement.xpath("supplemental-guidance").length > 0
			parse_supplemental_guidance(@control_id, enhancement.xpath("supplemental-guidance"))
		end

		if enhancement.xpath("references").length > 0
			parse_references(@control_id, enhancement.xpath("references"))
		end

		if enhancement.xpath("statement").length > 0
			parse_statements(@control_id, enhancement.xpath("statement"), @cnumber) # Because stupid NIST schema!
		end

	end

end


def parse_supplemental_guidance(cid, path)
	@description = path.xpath("description").text

	@relateds = []
	path.xpath("related").each do |relation|
		@relateds.push(relation.text)
	end

	MYSQL[:supplements].insert(
		'control_id' => cid,
		'description' => @description,
		'related' => @relateds.join(','),
		"created_at" => Time.now.strftime("%Y-%m-%d %H:%M:%S"),
		"updated_at" => Time.now.strftime("%Y-%m-%d %H:%M:%S")
	)
end


def parse_statements(cid, path, number)

	@number = number
	if path.xpath("number").text != ""
		@number = path.xpath("number").text
	end

	@description = path.xpath("description").text
	@is_odv = 0
	if @description.include? "\[Assignment:"
		@is_odv = 1
	end

	MYSQL[:statements].insert(
		'control_id' => cid,
		'number' => @number,
		'description' => @description,
		'is_odv' => @is_odv,
		"created_at" => Time.now.strftime("%Y-%m-%d %H:%M:%S"),
		"updated_at" => Time.now.strftime("%Y-%m-%d %H:%M:%S")
	)

	path.xpath("statement").each do |statement|
		parse_statements(cid, statement, "")
	end
end


def parse_baseline_impact(path)
	@baseline_impacts = { "LOW" => false, "MODERATE" => false, "HIGH" => false}

	path.search("baseline-impact").each do |baseline_impact|
		@baseline_impacts[baseline_impact.text] = true
	end

	@baseline_impacts
end


def parse_withdrawn(path)
	@number = path.xpath("number").text
	@is_withdrawn = path.xpath("withdrawn").text != ""

	if @is_withdrawn
		@incorporations = []
		path.xpath("withdrawn//incorporated-into").each do |incorporation|
			@incorporations.push(incorporation.text)
		end

		MYSQL[:withdrawals].insert(
			'number' => @number,
			'incorporated_into' => @incorporations.join(','),
			"created_at" => Time.now.strftime("%Y-%m-%d %H:%M:%S"),
			"updated_at" => Time.now.strftime("%Y-%m-%d %H:%M:%S")
		)
	end

	@is_withdrawn
end


def parse_references(cid, path)

	@references = []
	path.xpath("reference//item").each do |item|
		MYSQL[:references].insert(
			'control_id' => cid,
			'reference' => item.text,
			'link' => item.attr("href"),
			"created_at" => Time.now.strftime("%Y-%m-%d %H:%M:%S"),
			"updated_at" => Time.now.strftime("%Y-%m-%d %H:%M:%S")
		)
	end
end


def create_tables

	# Keep sequel from treating tinyint 0/1 as boolean
	MYSQL.convert_tinyint_to_bool = false

	puts "creating FAMILIES table..."
	MYSQL.create_table!(:families) do
		primary_key :id
		text :name
		text :acronym
		text :family_type
		datetime :created_at
		datetime :updated_at
	end
	puts "done\n"

	puts "creating CONTROLS table..."
	MYSQL.create_table!(:controls) do
		primary_key :id
		Integer :parent_id
		Integer :family_id
		text :family_name
		text :number
		text :title
		text :priority
		tinyint :is_baseline_impact_low, :size => 1
		tinyint :is_baseline_impact_moderate, :size => 1
		tinyint :is_baseline_impact_high, :size => 1
		tinyint :is_withdrawn, :size => 1
		tinyint :is_enhancement, :size => 1
		datetime :created_at
		datetime :updated_at
	end
	puts "done\n"

	puts "creating REFERENCES table..."
	MYSQL.create_table!(:references) do
		primary_key :id
		Integer :control_id
		text :reference
		String :link
		datetime :created_at
		datetime :updated_at
	end
	puts "done\n"

	puts "creating STATEMENTS table..."
	MYSQL.create_table!(:statements) do
		primary_key :id
		Integer :control_id
		String :number
		text :description
		tinyint :is_odv, :size => 1
		datetime :created_at
		datetime :updated_at
	end
	puts "done\n"

	puts "creating SUPPLEMENTS table..."
	MYSQL.create_table!(:supplements) do
		primary_key :id
		Integer :control_id
		text :description
		text :related
		datetime :created_at
		datetime :updated_at
	end
	puts "done\n"

	puts "creating WITHDRAWALS table..."
	MYSQL.create_table!(:withdrawals) do
		primary_key :id
		String :number
		String :incorporated_into
		datetime :created_at
		datetime :updated_at
	end
	puts "done\n"
end


######################################### Main ###################################################

# For reference:
# Ruby OptionParser documentation: http://docs.ruby-lang.org/en/2.1.0/OptionParser.html
# Sequel gem documentation: http://sequel.jeremyevans.net/documentation.html
# https://coderwall.com/p/03r98q/using-the-nokogiri-gem-to-parse-nested-xml-data-in-ruby
# http://stackoverflow.com/questions/11156781/xpath-in-nokogiri-returning-empty-array-whereas-i-am-expecting-to-have-result

# NOTES: This script was written under the assumption that you're using a MySQL database.
#		 If this is not the case, you'll have to tweak it a bit to use your specific adapter.
#		 The default name is listed below - feel free to change it to the name of your db.
#		 The script will drop/recreate all of the necessary tables for the control_freak
#		 application, so if you make any schema changes to the app you'll need to also update
#		 this script, otherwise any changes you've made the to database will be wiped out.

# example usage:
# ruby control_parser.rb -u root -p P4SSW0RD! -d control_freak_development

options = {}
OptionParser.new do |opts|
	opts.banner = "Usage: ruby control_parser.rb [options]"

	opts.on("-h", "--help", "Script options:") do
		puts opts
		exit
	end

	opts.on("-u username", "--user username", String, "Set database user (REQUIRED)") do |u|
		options[:username] = u
	end

	opts.on("-p password", "--password password", String, "Set database password (REQUIRED)") do |p|
		options[:password] = p
	end

	opts.on("-f filename", "--file filename", String, "Filename to parse (defaults to '800-53-controls.xml')") do |f|
		options[:filename] = f
	end

	opts.on("-o host", "--host hostname", String, "Database hostname (defaults to 'localhost')") do |h|
		options[:hostname] = h
	end

	opts.on("-d database", "--database database", String, "Set the database for the parser (defaults to 'control_freak_development')") do |d|
		options[:database] = d
	end

end.parse!

dbfile = options[:filename] ? options[:filename] : "800-53-controls.xml"
dbhost = options[:hostname] ? options[:hostname] : "localhost"
dbname = options[:database] ? options[:database] : "control_freak_development"
dbuser = options[:username] ? options[:username] : ""
dbpass = options[:password] ? options[:password] : ""

if dbuser == "" or dbpass == ""
	puts "Please enter the username and password for your database!\n\n"
	exit(0)
end

begin
	puts "Checking for database - creating one if it doen't exist..."
	client = Mysql2::Client.new(:host => dbhost, :username => dbuser, :password => dbpass)
	client.query("CREATE DATABASE IF NOT EXISTS #{dbname};")
	client.close
	puts "done"

	MYSQL = Sequel.connect(:adapter => 'mysql2', :host => dbhost, :database => dbname, :username => dbuser, :password => dbpass, :test => true)

	@doc = Nokogiri::XML(File.open(dbfile))
	@doc.remove_namespaces!

	create_tables()

	puts "Beginning XML parsing now..."
	@doc.xpath("//control").each do |control|
		parse_control(control)
	end
	puts "Completed XML parsing - please verify database is correct\n"
	exit(0)

rescue => error
	puts "ERROR PROCESSING: #{error.message}\n\nFULL ERROR:\n#{error.backtrace}"
end
