# NIST-SP-800-53-Toolkit

Sick of &#8984;-F-ing my way through PDFs, I took up the task of migrating the information in NIST SP 800-53 Revision 4 into more navigable formats.

## What you'll find here

### Raw docs

The PDF and the XML file are pulled directly from the [NIST SP library](http://csrc.nist.gov/publications/PubsSPs.html). These are the unedited versions, and I've really just put them here for quick reference.

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
  
