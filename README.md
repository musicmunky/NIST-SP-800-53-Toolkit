# NIST-SP-800-53-Toolkit

Sick of &#8984;-F-ing my way through PDFs, I took up the task of migrating the information in NIST SP 800-53 Revision 4 into more navigable formats.

**_Coming soon_**: I'm building out a simple, browser-based way to navigate all the information here. A web app-ified version of the docs, if you will. Stay tuned for a link (once I figure out hosting), and a separate repo with all the code.

## What you'll find here

### Raw docs

The PDF and the XML file are pulled directly from the [NIST SP library](http://csrc.nist.gov/publications/PubsSPs.html). These are the unedited versions, and I've really just put them here for quick reference. Feel free to use it however you see fit. I'm going to try my best to keep it up-to-date.

### MySQL exports

The SQL file is a MySQL self-contained, structure and data export. You can load the file into a MySQL install, and explore the following schema:

* families *# 18 rows*
  * family
  * acronym
* controls *# 922 rows - includes control enhancements*
  * family
  * number
  * title
  * priority
  * is_baseline_impact_low
  * is_baseline_impact_moderate
  * is_baseline_impact_high
  * is_withdrawn
  * is_enhancement
* references *# 331 rows*
  * number
  * reference *# E.g., document title*
  * link *# A hyper one*
* statements *# 1682 rows*
  * number
  * description
  * is_odv *# Some component of the description is a Madlib*
* supplemental_guidance *# 752 rows*
  * number
  * description
  * related *# Other pertinent controls*
* withdrawls *# 96 rows*
  * number
  * incorporated_into *# Some other control*

### SQLite file

This is a straight dump of the MySQL structure and data into a SQLite version, for lightweight reference.

### XLSX file

This Microsoft Excel file is a Workbook of Worksheets (for you guys that speak VBA) mapping to the tables in the above databases. Apologies for any crazy character formatting issues that may have sprouted up in translation.

### Text and SQL
A bunch of CSVs and SQL files for getting all the data into various databases. The row IDs and datetimes columns are to support standard data schemas for Rails app models.

### The script

This is **quick and dirty** Ruby/Nokogiri script to tear the XML file from NIST into pieces. The NIST schema is sort of wonky (e.g., the way numbers and statements are listed throughout is not optimal), so the script makes some assumptions. As a result, I had to go back and fill some of the gaps (e.g., references to families in the "controls" table) after the fact. It's not perfect, but meh, it works.
