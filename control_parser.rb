#!/home/tandrews/.rvm/rubies/ruby-2.2.1/bin/ruby
#####!/usr/local/bin/ruby

# This script processes the 800-53-controls.xml document provided by NIST
# (https://nvd.nist.gov/static/feeds/xml/sp80053/rev4/800-53-controls.xml), and
# parses various components into a MYSQL database.
# Quick and dirty, but it works... More or less.

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
	MYSQL.convert_tinyint_to_bool = false

	puts "creating FAMILIES table..."
	MYSQL.create_table(:families) do
		primary_key :id
		text :name
		text :acronym
		text :family_type
		datetime :created_at
		datetime :updated_at
	end
	puts "done\n"

	puts "creating CONTROLS table..."
	MYSQL.create_table(:controls) do
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
	MYSQL.create_table(:references) do
		primary_key :id
		Integer :control_id
		text :reference
		String :link
		datetime :created_at
		datetime :updated_at
	end
	puts "done\n"

	puts "creating STATEMENTS table..."
	MYSQL.create_table(:statements) do
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
	MYSQL.create_table(:supplements) do
		primary_key :id
		Integer :control_id
		text :description
		text :related
		datetime :created_at
		datetime :updated_at
	end
	puts "done\n"

	puts "creating WITHDRAWALS table..."
	MYSQL.create_table(:withdrawals) do
		primary_key :id
		String :number
		String :incorporated_into
		datetime :created_at
		datetime :updated_at
	end
	puts "done\n"
end


######################################### Main ###################################################

# https://coderwall.com/p/03r98q/using-the-nokogiri-gem-to-parse-nested-xml-data-in-ruby
# http://stackoverflow.com/questions/11156781/xpath-in-nokogiri-returning-empty-array-whereas-i-am-expecting-to-have-result

DEFAULT_FILE = '800-53-controls.xml'
MYSQL = Sequel.connect(:adapter => 'mysql2', :host => "localhost", :database => "DBNAME", :username => "DBUSERNAME", :password=>'DBPASSWORD!')

@file = ARGV.shift || DEFAULT_FILE
@doc = Nokogiri::XML(File.open(@file))
@doc.remove_namespaces!

create_tables()

puts "Beginning XML parsing now..."
@doc.xpath("//control").each do |control|
	parse_control(control)
end
puts "Completed XML parsing - please verify database is correct\n"

