#!/usr/local/bin/ruby

# This script processes the 800-53-controls.xml document provided by NIST
# (https://nvd.nist.gov/static/feeds/xml/sp80053/rev4/800-53-controls.xml), and
# parses various components into a MYSQL database.
# Quick and dirty, but it works... More or less.

require 'nokogiri'
require 'mysql2'
require 'sequel'

DEFAULT_FILE = '800-53-controls.xml'
#MYSQL = Mysql2::Client.new(:host => "localhost", :database => "800-53", :username => "root")
MYSQL = Sequel.connect(:adapter => 'mysql2', :host => "localhost", :database => "800-53", :username => "root")

def parse_control(path)
  @family = path.xpath("family").text
  @number = path.xpath("number").text
  @title = path.xpath("title").text
  @priority = path.xpath("priority").text
  @baseline_impacts = parse_baseline_impact(path)
  @withdrawn = parse_withdrawn(path)

  MYSQL[:controls].insert(
    'family' => @family,
    'number' => @number,
    'title' => @title,
    'priority' => @priority,
    'is_baseline_impact_low' => @baseline_impacts['LOW'],
    'is_baseline_impact_moderate' => @baseline_impacts['MODERATE'],
    'is_baseline_impact_high' => @baseline_impacts['HIGH'],
    'is_withdrawn' => @withdrawn
  )

  parse_supplemental_guidance(path)
  parse_statements(path.xpath("statement"), @number) # Because stupid NIST schema!
  parse_control_enhancements(path)
  parse_references(path)
end

def parse_supplemental_guidance(path)
  @number = path.xpath("number").text
  @is_supplemental_guidance = path.xpath("supplemental-guidance").text != ""

  if @is_supplemental_guidance
    @description = path.xpath("supplemental-guidance//description").text

    @relateds = []
    path.xpath("supplemental-guidance//related").each do |relation|
      @relateds.push(relation.text)
    end

    MYSQL[:supplemental_guidance].insert(
      'number' => @number,
      'description' => @description,
      'related' => @relateds.join(',')
    )
  end
end

def parse_statements(path, number)
  @number
  @is_statement = path.text != ""

  if @is_statement
    if number == ""
      @number = path.xpath("number").text
    else
      @number = number
    end

    @description = path.xpath("description").text

    MYSQL[:statements].insert(
      'number' => @number,
      'description' => @description
    )

    path.xpath("statement").each do |statement|
      parse_statements(statement, "")
    end
  end
end

def parse_baseline_impact(path)
  @baseline_impacts = { "LOW" => false, "MODERATE" => false, "HIGH" => false}

  path.xpath("baseline-impact").each do |baseline_impact|
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

    MYSQL[:withdrawls].insert(
      'number' => @number,
      'incorporated_into' => @incorporations.join(',')
    )
  end

  @is_withdrawn
end

def parse_references(path)
  @number = path.xpath("number").text
  @is_references = path.xpath("references").text != ""

  if @is_references
    @references = []
    path.xpath("references//reference//item").each do |item|
      MYSQL[:references].insert(
        'number' => @number,
        'reference' => item.text,
        'link' => item.attr("href")
      )
    end
  end
end

def parse_control_enhancements(path)
  @number = path.xpath("number").text
  @is_control_enhancement = path.xpath("control-enhancements").text != ""

  if @is_control_enhancement
    path.xpath("control-enhancements//control-enhancement").each do |enhancement|
      parse_control(enhancement)
    end
  end
end

# Main
@file = ARGV.shift || DEFAULT_FILE
@doc = Nokogiri::XML(File.open(@file))

@doc.xpath("//controls//control").each do |control|
  parse_control(control)
end
