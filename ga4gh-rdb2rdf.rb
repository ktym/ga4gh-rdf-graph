#!/usr/bin/env ruby-2.1
#
# Script to convert GA4GH graph RDB into RDF
#
# GA4GH graph RDB schema
#   * https://github.com/ga4gh/server/blob/graph/tests/data/graphs/graphSQL_v023.sql
#
# Usage:
#   % ga4gh-rdb2rdf.rb path/to/graph.db > path/to/graph.ttl
#

# DONE: replace :join
# DONE: rdf:type and rdfs:label for subject
# DONE: validate() to check emptiness

module GA4GH
  module Graph
    TABLES = [
      "Allele",
      "AlleleCall",
      "AllelePathItem",
      "CallSet",
      "FASTA",
      "GraphJoin",
      "GraphJoin_ReferenceSet_Join",
      "GraphJoin_VariantSet_Join",
      "Reference",
      "ReferenceAccession",
      "ReferenceSet",
      "ReferenceSetAccession",
      "Reference_ReferenceSet_Join",
      "Sequence",
      "VariantSet",
      "VariantSet_CallSet_Join",
    ]
  end
end

class GA4GH::Graph::RDB2Dump
  attr_reader :dir

  def initialize(rdb_file, dump_dir = nil)
    unless dump_dir
      path = File.dirname(rdb_file)
      name = File.basename(rdb_file, ".db")
      dump_dir = File.join(path, name)
    end
    unless Dir.exists?(dump_dir)
      Dir.mkdir(dump_dir)
    end
    @file = rdb_file
    @dir = dump_dir
  end

  def create
    GA4GH::Graph::TABLES.each do |table|
      command = "echo 'select * from #{table};' | sqlite3 #{@file} > #{@dir}/#{table}"
      $stderr.puts(command)
      system(command)
    end
  end
end

class GA4GH::Graph::Dump2RDF
  PREFIX = "http://ga4gh.org/graph/rdf"

  def self.prefix
    [
      "@prefix : <#{PREFIX}/ontology#> .",
      "@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .",
      "@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .",
      "@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .",
      ""
    ]
  end

  def initialize(file)
    File.open(file).each do |line|
      convert(line.strip.split('|'))
    end
  end

  def convert(data)
    raise NotImplementedError
  end

  def validate(*values)
    values.each do |value|
      if value.to_s.empty?
        raise ArgumentError
      end
    end
  end

  def triple(s, p, o)
    validate(s, p, o)
    puts [s, p, o].join("\t") + " ."
  end

  def quote(value)
    return value.gsub('\\', '\\\\').gsub("\t", '\\t').gsub("\n", '\\n').gsub("\r", '\\r').gsub('"', '\\"').inspect
  end

  def integer(value)
    value.to_i
  end

  def real(value)
    value.to_f
  end

  def boolean(value)
    return value.match(/TRUE|1/i) ? "true" : "false"
  end

  def date(value)
    # value = "2015-07-20"
    return %Q("#{value}"^^xsd:date)
  end

  def allele_uri(alleleID)
    validate(alleleID)
    return "<#{PREFIX}/Allele/#{alleleID}>"
  end

  def allele_call_uri(alleleID, callSetID)
    validate(alleleID, callSetID)
    return "<#{PREFIX}/AlleleCall/#{alleleID}/#{callSetID}>"
  end

  def allele_path_item_uri(alleleID, pathItemIndex)
    validate(alleleID, pathItemIndex)
    return "<#{PREFIX}/AllelePathItem/#{alleleID}/#{pathItemIndex}>"
  end

  def call_set_uri(callSetID)
    validate(callSetID)
    return "<#{PREFIX}/CallSet/#{callSetID}>"
  end

  def fasta_uri(fastaID)
    validate(fastaID)
    return "<#{PREFIX}/FASTA/#{fastaID}>"
  end

  def graph_join_uri(graphJoinID)
    validate(graphJoinID)
    return "<#{PREFIX}/GraphJoin/#{graphJoinID}>"
  end

  def reference_uri(referenceID)
    validate(referenceID)
    return "<#{PREFIX}/Reference/#{referenceID}>"
  end

  def reference_accession_uri(referenceAccessionID)
    validate(referenceAccessionID)
    return "<#{PREFIX}/ReferenceAccession/#{referenceAccessionID}>"
  end

  def reference_set_uri(referenceSetID)
    validate(referenceSetID)
    return "<#{PREFIX}/ReferenceSet/#{referenceSetID}>"
  end

  def reference_set_accession_uri(referenceSetAccessionID)
    validate(referenceSetAccessionID)
    return "<#{PREFIX}/ReferenceSetAccession/#{referenceSetAccessionID}>"
  end

  def sequence_uri(sequenceID)
    validate(sequenceID)
    return "<#{PREFIX}/Sequence/#{sequenceID}>"
  end

  def taxonomy_uri(taxonomyID)
    #validate(taxonomyID)
    return "<http://identifiers.org/taxonomy/#{taxonomyID}>"
  end

  def variant_set_uri(variantSetID)
    validate(variantSetID)
    return "<#{PREFIX}/VariantSet/#{variantSetID}>"
  end
end

# RDB schema:
#
#   CREATE TABLE Allele (
#     ID            INTEGER PRIMARY KEY,
#     variantSetID  INTEGER REFERENCES VariantSet(ID),
#     name          TEXT
#   ); -- Naming the allele is optional
#
# RDF model:
#
#   <AlleleID>
#     :variantSetID  <VariantSetID> ;
#     :name          "text" .
#
class GA4GH::Graph::Allele < GA4GH::Graph::Dump2RDF
  def convert(data)
    subject = allele_uri(data[0])
    triple(subject, "rdf:type", ":Allele")
    triple(subject, "rdfs:label", quote("Allele/#{data[0]}"))
    triple(subject, ":variantSetID", variant_set_uri(data[1]))
    triple(subject, ":name", quote(data[2]))
  end
end

# RDB schema:
#
#   CREATE TABLE AlleleCall (
#     alleleID   INTEGER NOT NULL REFERENCES allele(ID),
#	    callSetID  INTEGER NOT NULL REFERENCES CallSet(ID),
#	    ploidy     INTEGER NOT NULL,
#	    PRIMARY KEY(alleleID, callSetID)
#   );
#
# RDF model:
#
#   <AlleleCallID>
#     :alleleID   <AlleleID> ;
#     :callSetID  <CallSetID> ;
#     :ploidyID   ###^^xsd:integer .
#
class GA4GH::Graph::AlleleCall < GA4GH::Graph::Dump2RDF
  def convert(data)
    subject = allele_call_uri(data[0], data[1])
    triple(subject, "rdf:type", ":AlleleCall")
    triple(subject, "rdfs:label", quote("AlleleCall/#{data[0]}/#{data[1]}"))
    triple(subject, ":alleleID", allele_uri(data[0]))
    triple(subject, ":callSetID", call_set_uri(data[1]))
    triple(subject, ":ploidy", integer(data[2]))
  end
end

# RDB schema:
#
#   CREATE TABLE AllelePathItem (
#     alleleID INTEGER REFERENCES allele(ID),
#     pathItemIndex    INTEGER NOT NULL, -- zero-based index of this pathItem within the entire path
#     sequenceID       INTEGER NOT NULL REFERENCES Sequence(ID),
#     start            INTEGER NOT NULL,
#     length           INTEGER NOT NULL,
#     strandIsForward  BOOLEAN NOT NULL,
#     PRIMARY KEY(alleleID, pathItemIndex)
#   );
#
# RDF model:
#
#   <AlleleID/AllelePathItem>
#     :alleleID         <AlleleID> ;
#     :pathItemIndex    ###^^xsd:integer ;
#     :sequenceID       <SequenceID> ;
#     :start            ###^^xsd:integer ;
#     :length           ###^^xsd:integer ;
#     :strandIsForward  boolean .
#
class GA4GH::Graph::AllelePathItem < GA4GH::Graph::Dump2RDF
  def convert(data)
    subject = allele_path_item_uri(data[0], data[1])
    triple(subject, "rdf:type", ":AllelePathItem")
    triple(subject, "rdfs:label", quote("AllelePathItem/#{data[0]}/#{data[1]}"))
    triple(subject, ":alleleID", allele_uri(data[0]))
    triple(subject, ":pathItemIndex", integer(data[1]))
    triple(subject, ":sequenceID", sequence_uri(data[2]))
    triple(subject, ":start", integer(data[3]))
    triple(subject, ":length", integer(data[4]))
  end
end

# RDB schema:
#
#   CREATE TABLE CallSet (
#     ID        INTEGER PRIMARY KEY,
#   	name      TEXT, -- can be null?
#   	sampleID  TEXT
#   );
#
# RDF model:
#
#   <CallSetID>
#     :name      "text" ;
#     :sampleID  "text" .   # why not URI?
#
class GA4GH::Graph::CallSet < GA4GH::Graph::Dump2RDF
  def convert(data)
    subject = call_set_uri(data[0])
    triple(subject, "rdf:type", ":CallSet")
    triple(subject, "rdfs:label", quote("CallSet/#{data[0]}"))
    triple(subject, ":name", data[1])
    triple(subject, ":sampleID", data[2])  # TODO: check if this should be sample_uri
  end
end

# RDB schema:
#
#   CREATE TABLE FASTA (
#     ID        INTEGER PRIMARY KEY,
#    	fastaURI  TEXT NOT NULL
#   );
#
# RDF model:
#
#   <FastaID>
#     :fastaURI  <URI> .
#
class GA4GH::Graph::FASTA < GA4GH::Graph::Dump2RDF
  def convert(data)
    subject = fasta_uri(data[0])
    triple(subject, "rdf:type", ":FASTA")
    triple(subject, "rdfs:label", quote("FASTA/#{data[0]}"))
    triple(subject, ":fastaURI", "<file://#{data[1]}>")
  end
end

# RDB schema:
#
#   CREATE TABLE GraphJoin (
#     ID                    INTEGER PRIMARY KEY,
#	    -- by convention, side1 < side2 in the lexicographic ordering defined by (sequenceID, position, forward).
#   	side1SequenceID       INTEGER NOT NULL REFERENCES Sequence(ID),
#   	side1Position         INTEGER NOT NULL, -- 0 based indexing, counting from 5' end of sequence.
#    	side1StrandIsForward  BOOLEAN NOT NULL, -- true if this side joins to 5' end of the base
#   	side2SequenceID       INTEGER NOT NULL REFERENCES Sequence(ID),
#   	side2Position         INTEGER NOT NULL,
#   	side2StrandIsForward  BOOLEAN NOT NULL
#   );
#
# RDF model:
#
#   <GraphJoinID>
#     :side1SequenceID      <SequenceID> ;
#     :side1Position        ###^xsd:integer ;
#     :side1StrandIsForward boolean;
#     :side2SequenceID      <SequenceID> ;
#     :side2Position        ###^xsd:integer ;
#     :side2StrandIsForward boolean .
#
class GA4GH::Graph::GraphJoin < GA4GH::Graph::Dump2RDF
  def convert(data)
    subject = graph_join_uri(data[0])
    triple(subject, "rdf:type", ":GraphJoin")
    triple(subject, "rdfs:label", quote("GraphJoin/#{data[0]}"))
    triple(subject, ":side1SequenceID", sequence_uri(data[1]))
    triple(subject, ":side1Position", integer(data[2]))
    triple(subject, ":side1StrandIsForward", boolean(data[3]))
    triple(subject, ":side2SequenceID", sequence_uri(data[4]))
    triple(subject, ":side2Position", integer(data[5]))
    triple(subject, ":side2StrandIsForward", boolean(data[6]))
  end
end

# RDB schema:
#
#   CREATE TABLE GraphJoin_ReferenceSet_Join (
#     graphJoinID     INTEGER NOT NULL REFERENCES GraphJoin(ID),
#   	referenceSetID  INTEGER NOT NULL REFERENCES ReferenceSet(ID),
#   	PRIMARY KEY(graphJoinID, referenceSetID)
#   );
#
# RDF model:
#
#   <GraphJoinID> :join <ReferenceSetID> .
#   <ReferenceSetID> :join <GraphJoinID> .
#
class GA4GH::Graph::GraphJoin_ReferenceSet_Join < GA4GH::Graph::Dump2RDF
  def convert(data)
    node0 = graph_join_uri(data[0])
    node1 = reference_set_uri(data[1])
    triple(node0, ":referenceSetID", node1)
    triple(node1, ":graphJoinID", node0)
  end
end

# RDB schema:
#
#   CREATE TABLE GraphJoin_VariantSet_Join (
#     graphJoinID   INTEGER NOT NULL REFERENCES GraphJoin(ID),
#   	variantSetID  INTEGER NOT NULL REFERENCES VariantSet(ID),
#   	PRIMARY KEY(graphJoinID, variantSetID)
#   );
#
# RDF model:
#
#   <GraphJoinID> :join <VariantSetID> .
#   <VariantSetID> :join <GraphJoinID> .
#
class GA4GH::Graph::GraphJoin_VariantSet_Join < GA4GH::Graph::Dump2RDF
  def convert(data)
    node0 = graph_join_uri(data[0])
    node1 = variant_set_uri(data[1])
    triple(node0, ":variantSetID", node1)
    triple(node1, ":graphJoinID", node0)
  end
end

# RDB schema:
#
#   CREATE TABLE Reference (
#     ID                INTEGER PRIMARY KEY,
#    	name              TEXT NOT NULL,
#    	updateTime        DATE NOT NULL,
#    	sequenceID        INTEGER NOT NULL REFERENCES Sequence(ID),
#    	start             INTEGER, -- if null, reference starts at position 0 of the underlying sequence
#    	length            INTEGER, -- if null, this is calculated as (sequence.lenght - start)
#    	md5checksum       TEXT, -- if null, assume sequence.md5checksum
#    	-- the below metadata are defined as in the corresponding fields in the Avro Reference record.
#    	isDerived         BOOLEAN,
#    	sourceDivergence  REAL,
#    	ncbiTaxonID       INTEGER,
#    	isPrimary         BOOLEAN
#   );
#
# RDF model:
#
#   <ReferenceID>
#     :name             "text" ;
#     :updateTime       ###^^xsd:datetime ;
#     :sequenceID       <SequenceID> ;
#     :start            ###^^xsd:integer ;
#     :length           ###^^^xsd:integer ;
#     :md5checksum      "text" ;
#     :isDerived        boolean ;
#     :sourceDivergence ###^^xsd:float ;  # why real?
#     :ncbiTaxonID      <http://identifiers.org/taxonomy/9606> ;
#     :isPrimary        boolean .
#
class GA4GH::Graph::Reference < GA4GH::Graph::Dump2RDF
  def convert(data)
    subject = reference_uri(data[0])
    triple(subject, "rdf:type", ":Reference")
    triple(subject, "rdfs:label", quote("Reference/#{data[0]}"))
    triple(subject, ":name", quote(data[1]))
    triple(subject, ":updateTime", date(data[2]))
    triple(subject, ":sequenceID", sequence_uri(data[3]))
    triple(subject, ":start", integer(data[4]))
    triple(subject, ":length", integer(data[5]))
    triple(subject, ":md5checksum", quote(data[6]))
    triple(subject, ":isDerived", boolean(data[7]))
    triple(subject, ":ncbiTaxonID", taxonomy_uri(data[8])) if data[8]
    triple(subject, ":isPrimary", boolean(data[9]))
  end
end

# RDB schema:
#
#   CREATE TABLE ReferenceAccession (
#     ID           INTEGER PRIMARY KEY,
#   	referenceID  INTEGER NOT NULL REFERENCES Reference(ID),
#   	accessionID  TEXT NOT NULL
#   );
#
# RDF model:
#
#   <ReferenceAccessionID>
#     :referenceID <ReferenceID> ;
#     :accessionID  "text" .  # not URI?
#
class GA4GH::Graph::ReferenceAccession < GA4GH::Graph::Dump2RDF
  def convert(data)
    subject = reference_accession_uri(data[0])
    triple(subject, "rdf:type", ":ReferenceAccession")
    triple(subject, "rdfs:label", quote("ReferenceAccession/#{data[0]}"))
    triple(subject, ":referenceID", reference_uri(data[1]))
    triple(subject, ":accessionID", quote(data[2]))
  end
end

# RDB schema:
#
#   CREATE TABLE ReferenceSet (
#     ID           INTEGER PRIMARY KEY,
#   	ncbiTaxonID  INT, -- may differ from ncbiTaxonID of contained Reference record
#   	description  TEXT,
#   	assemblyID   TEXT,
#   	isDerived    BOOLEAN NOT NULL
#   );
#
# RDF model:
#
#   <RererenceSetID>
#     :ncbiTaxon    <http://identifiers.org/taxonomy/9606> ;
#     :description  "text" ;
#     :assemblyID   "text" ;  # not URI?
#     :isDerived     boolean .
#
class GA4GH::Graph::ReferenceSet < GA4GH::Graph::Dump2RDF
  def convert(data)
    subject = reference_set_uri(data[0])
    triple(subject, "rdf:type", ":ReferenceSet")
    triple(subject, "rdfs:label", quote("ReferenceSet/#{data[0]}"))
    triple(subject, ":ncbiTaxonID", taxonomy_uri(data[1]))
    triple(subject, ":description", quote(data[2]))
    triple(subject, ":assemblyID", quote(data[3]))
    triple(subject, ":isDerived", boolean(data[4]))
  end
end

# RDB schema:
#
#   CREATE TABLE ReferenceSetAccession (
#     ID              INTEGER PRIMARY KEY,
#   	referenceSetID  INTEGER NOT NULL REFERENCES ReferenceSet(ID),
#   	accessionID     TEXT NOT NULL
#   );
#
# RDF model:
#
#   <ReferenceSetAccessionID>
#     :referenceSetID  <ReferenceSetID> ;
#     :accessionID     "text" .   # not URI?
#
class GA4GH::Graph::ReferenceSetAccession < GA4GH::Graph::Dump2RDF
  def convert(data)
    subject = reference_set_accession_uri(data[0])
    triple(subject, "rdf:type", ":ReferenceSetAccession")
    triple(subject, "rdfs:label", quote("ReferenceSetAccession/#{data[0]}"))
    triple(subject, ":referenceSetID", reference_set_uri(data[1]))
    triple(subject, ":accessionID", quote(data[2]))
  end
end

# RDB schema:
#
#   CREATE TABLE Reference_ReferenceSet_Join (
#     referenceID     INTEGER NOT NULL REFERENCES Reference(ID),
#   	referenceSetID  INTEGER NOT NULL REFERENCES ReferenceSet(ID),
#   	PRIMARY KEY(referenceID, referenceSetID)
#   );
#
# RDF model:
#
#   <ReferenceID> :join <ReferenceSetID> .
#   <ReferenceSetID> :join <ReferenceID> .
#
class GA4GH::Graph::Reference_ReferenceSet_Join < GA4GH::Graph::Dump2RDF
  def convert(data)
    node0 = reference_uri(data[0])
    node1 = reference_set_uri(data[1])
    triple(node0, ":referenceSetID", node1)
    triple(node1, ":referenceID", node0)
  end
end

# RDB schema:
#
#   CREATE TABLE Sequence (
#     ID                  INTEGER PRIMARY KEY,
#   	fastaID             INTEGER NOT NULL REFERENCES FASTA(ID), -- the FASTA file that contains this sequence's bases.
#   	sequenceRecordName  TEXT NOT NULL, -- access to the sequence bases in the FASTA file ONLY.
#   	md5checksum         TEXT NOT NULL, -- checksum of the base sequence as found in the FASTA record.
#   	length              INTEGER NOT NULL -- length of the base sequence as found in the FASTA record.
#   );
#
# RDF model:
#
#   <SequenceID>
#     :fastaID             <FastaID> ;
#     :sequenceRecordName  "text" ;
#     :md5checksum         "text" ;
#     :length              ###^^xsd:integer .
#
class GA4GH::Graph::Sequence < GA4GH::Graph::Dump2RDF
  def convert(data)
    subject = sequence_uri(data[0])
    triple(subject, "rdf:type", ":Sequence")
    triple(subject, "rdfs:label", quote("Sequence/#{data[0]}"))
    triple(subject, ":fastaID", fasta_uri(data[1]))
    triple(subject, ":sequenceRecordName", quote(data[2]))
    triple(subject, ":md5checksum", quote(data[3]))
    triple(subject, ":length", integer(data[4]))
  end
end

# RDB schema:
#
#   CREATE TABLE VariantSet (
#     ID              INTEGER PRIMARY KEY,
#   	referenceSetID  INTEGER NOT NULL REFERENCES ReferenceSet(ID),
#   	name            TEXT
#   );
#
# RDF model:
#
#   <VariantSetID>
#     :referenceSetID <ReferenceSetID> ;
#     :name           "text" .
#
class GA4GH::Graph::VariantSet < GA4GH::Graph::Dump2RDF
  def convert(data)
    subject = variant_set_uri(data[0])
    triple(subject, "rdf:type", ":VariantSet")
    triple(subject, "rdfs:label", quote("VariantSet/#{data[0]}"))
    triple(subject, ":referenceSetID", reference_set_uri(data[1]))
    triple(subject, ":name", quote(data[2]))
  end
end

# RDB schema:
#
#   CREATE TABLE VariantSet_CallSet_Join (
#     variantSetID  INTEGER NOT NULL REFERENCES VariantSet(ID),
#   	callSetID     INTEGER NOT NULL REFERENCES CallSet(ID),
#   	PRIMARY KEY(variantSetID, callSetID)
#   );
#
# RDF model:
#
#   <VariantSetID> :join <CallSetID> .
#   <CallSetID> :join <VariantSetID> .
#
class GA4GH::Graph::VariantSet_CallSet_Join < GA4GH::Graph::Dump2RDF
  def convert(data)
    node0 = variant_set_uri(data[0])
    node1 = call_set_uri(data[1])
    triple(node0, ":callSetID", node1)
    triple(node1, ":variantSetID", node0)
  end
end


if __FILE__ == $0
  rdb_file = ARGV.shift
  dump_dir = ARGV.shift

  dump = GA4GH::Graph::RDB2Dump.new(rdb_file, dump_dir)
  dump.create

  puts GA4GH::Graph::Dump2RDF.prefix
  GA4GH::Graph::TABLES.each do |klass|
    $stderr.puts("Converting #{klass} ...")
    Object.const_get("GA4GH::Graph::#{klass}").new("#{dump.dir}/#{klass}")
  end
end
