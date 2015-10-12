#!/usr/bin/env ruby

require "rubygems"
require "net/http"
require "uri"
require "cgi"
require "json"  # gem install json

class SPARQL

  attr :prefix_hash

  def initialize(url)
    @endpoint = url
    uri = URI.parse(url)

    @host = uri.host
    @port = uri.port
    @path = uri.path

    @user = uri.user
    @pass = uri.password

    @prefix_hash = {}

    Net::HTTP.version_1_2
  end

  def host
    return @endpoint
  end

  def prefix
    ary = []
    @prefix_hash.sort.each { |key, value|
      ary << "PREFIX #{key}: <#{value}>\n"
    }
    return ary.join
  end

  def query(sparql, opts={}, &block)
    result = ""

    case opts[:format]
    when "xml"
      format = "application/sparql-results+xml"
    when "json"
      format = "application/sparql-results+json"
    else # tabular text
      format = "application/sparql-results+json"
    end

    Net::HTTP.start(@host, @port) do |http|
      if timeout = ENV['SPARQL_TIMEOUT']
        http.read_timeout = timeout.to_i
      end

      sparql_qry = prefix + sparql
      sparql_str = CGI.escape(sparql_qry)

      path = "#{@path}?query=#{sparql_str}"

      if $DEBUG
        $stderr.puts "SPARQL_ENDPOINT host: #{@host}, port: #{@port}, path: #{@path}, user: #{@user}, pass: #{@pass}"
        $stderr.puts "SPARQL_TIMEOUT timeout: #{http.read_timeout} seconds"
        $stderr.puts sparql_qry
        $stderr.puts path
      end

      req = Net::HTTP::Get.new(path, {"Accept" => "#{format}"})
      if @user and @pass
        req.basic_auth @user, @pass
      end
      http.request(req) { |res|
        if block and opts[:format] # xml or json
          yield res.body
        else # tabular text
          result += res.body
        end
      }
    end

    if opts[:format] # xml or json
      return result
    else # generate tabular text
      if $DEBUG
        $stderr.puts result
      end
      table = format_json(result)
      if block
        yield table
      else
        return table
      end
    end
  end

  def find(keyword, opts={}, &block)
    sparql = "select ?s ?p ?o where { ?s ?t '#{keyword}'. ?s ?p ?o . }"
    query(sparql, opts, &block)
  end

  def head(opts={}, &block)
    limit  = opts[:limit] || 20
    offset = (opts[:offset] || 1).to_i
    sparql = "select ?s ?p ?o where { ?s ?p ?o . } offset #{offset} limit #{limit}"
    query(sparql, opts, &block)
  end

  def prefix_default
    @prefix_hash = {
      "rdf"       => "http://www.w3.org/1999/02/22-rdf-syntax-ns#",
      "rdfs"      => "http://www.w3.org/2000/01/rdf-schema#",
      "owl"       => "http://www.w3.org/2002/07/owl#",
      "xsd"       => "http://www.w3.org/2001/XMLSchema#",
      "pext"      => "http://proton.semanticweb.org/protonext#",
      "psys"      => "http://proton.semanticweb.org/protonsys#",
      "xhtml"     => "http://www.w3.org/1999/xhtml#",
      "dc"        => "http://purl.org/dc/elements/1.1/",
      "dcterms"   => "http://purl.org/dc/terms/",
      "foaf"      => "http://xmlns.com/foaf/0.1/",
      "skos"      => "http://www.w3.org/2004/02/skos/core#",
      "void"      => "http://rdfs.org/ns/void#",
      "dbpedia"   => "http://dbpedia.org/resource/",
      "dbp"       => "http://dbpedia.org/property/",
      "dbo"       => "http://dbpedia.org/ontology/",
      "yago"      => "http://dbpedia.org/class/yago/",
      "fb"        => "http://rdf.freebase.com/ns/",
      "sioc"      => "http://rdfs.org/sioc/ns#",
      "geo"       => "http://www.w3.org/2003/01/geo/wgs84_pos#",
      "geonames"  => "http://www.geonames.org/ontology#",
      "bibo"      => "http://purl.org/ontology/bibo/",
      "prism"     => "http://prismstandard.org/namespaces/basic/2.1/",
    }
  end

  private

  def format_json(json)
    begin
      hash = JSON.parse(json)
      head = hash["head"]["vars"]
      body = hash["results"]["bindings"]
    rescue
      return ""
    end
    text = ""
    text << head.join("\t") + "\n"
    body.each do |result|
      ary = []
      head.each do |key|
        data = result[key] || { "type" => '', "value" => ''}
        if data["type"] == "uri"
          uri = '<' + data["value"].gsub('\\', '') + '>'
          ary << uri
        else
          val = data["value"].gsub('\/', '/')
          ary << val
        end
      end
      text << ary.join("\t") + "\n"
    end
    return text
  end

end  # class SPARQL


### Command line UI

if __FILE__ == $0

def help
  puts <<HELP

Usage:

  Query the SPARQL endpoint by SPARQL or a keyword.
  Result will be printed in tabular text format by default.

  Available alternative formats are:
    * "json" for "application/sparql-result+json"
    * "xml" for "application/sparql-result+xml".

  # Show the SPARQL endpoint URL in use
  > sparql.rb host

  # Show a list of pre-defined prefixes
  > sparql.rb prefix

  # SPARQL query against the endpoint without pre-defined prefixes
  > sparql.rb query "SPARQL" [format]

  # SPARQL query against the endpoint including default prefixes
  > sparql.rb q "SPARQL" [format]

  # SPARQL query in a file against the endpoint without pre-defined prefixes
  > sparql.rb file sparql.txt [format]

  # SPARQL query in a file against the endpoint including default prefixes
  > sparql.rb f sparql.txt [format]

  # Search by a keyword against literal objects
  > sparql.rb find "keyword" [format]

  # Peek triples in the store
  > sparql.rb head [limit [offset [format]]]

Environmental variables:

  Specify SPARQL endpoint by the environmental variable 'SPARQL_ENDPOINT'.
  Default is "http://beta.sparql.uniprot.org/sparql"

  # for B shell
  > export SPARQL_ENDPOINT="http://example.org/sparql"

  # for C shell
  > setenv SPARQL_ENDPOINT "http://example.org/sparql"

  If the endpoint requires Basic HTTP authentication, encode the username
  and password as "http://username:password@example.org/sparql".

  The default timeout is 60 seconds. You can extend or shorten the length
  by the 'SPARQL_TIMEOUT' environmental variable.

  # for B shell
  > export SPARQL_TIMEOUT=300

  # for C shell
  > setenv SPARQL_TIMEOUT 300

HELP
end

def usage
  puts <<USAGE
Help:

  > sparql.rb help

Examples:

  # Set a SPARQL endpoint
  > export SPARQL_ENDPOINT="http://example.org/sparql"

  # Show the SPARQL endpoint
  > sparql.rb host

  # Show a list of pre-defined prefixes
  > sparql.rb prefix

  # Query with pre-defined prefixes
  > sparql.rb q 'select * where { ?s ?p ?o . } limit 1000'

  # Query without pre-defined prefixes
  > sparql.rb query 'select * where { ?s ?p ?o . } limit 1000'
  > sparql.rb query 'select * where { ?s ?p ?o . } limit 1000' json
  > sparql.rb query 'select * where { ?s ?p ?o . } limit 1000' xml

  # Query in a file with pre-defined prefixes
  > sparql.rb f sparql.txt

  # Query in a file without pre-defined prefixes
  > sparql.rb file sparql.txt
  > sparql.rb file sparql.txt json
  > sparql.rb file sparql.txt xml

  # Search by a keyword against literal objects
  > sparql.rb find "fuga"
  > sparql.rb find "fuga" json
  > sparql.rb find "fuga" xml

  # Peek triples in the store with limit and offset
  > sparql.rb head
  > sparql.rb head 10
  > sparql.rb head 10 50 
  > sparql.rb head 10 50 json
  > sparql.rb head 10 50 xml

USAGE
end

host = ENV['SPARQL_ENDPOINT'] || "http://beta.sparql.uniprot.org/sparql"
serv = SPARQL.new(host)

command = ARGV.shift
arguments = ARGV

case command
when "host"
  puts serv.host
when "prefix"
  serv.prefix_default
  puts serv.prefix
when "query", "q"
  serv.prefix_default if command == "q"
  if arguments.size > 0
    sparql = arguments.shift
    format = arguments.shift
    $stderr.puts "WARNING: invalid format #{format} (use 'xml' or 'json')" if format and not format[/(xml|json)/]
    serv.query(sparql, :format => format) {|x| print x}
  else
    $stderr.puts "ERROR: missing SPARQL to query."
    $stderr.puts "> sparql.rb query SPARQL [format]"
  end
when "file", "f"
  serv.prefix_default if command == "f"
  if arguments.size > 0
    sparql = File.read(arguments.shift)
    format = arguments.shift
    $stderr.puts "WARNING: invalid format #{format} (use 'xml' or 'json')" if format and not format[/(xml|json)/]
    serv.query(sparql, :format => format) {|x| print x}
  else
    $stderr.puts "ERROR: missing SPARQL query file"
    $stderr.puts "> sparql.rb file <filename> [format]"
  end
when "find"
  if arguments.size > 0
    keyword = arguments.shift
    format = arguments.shift
    $stderr.puts "WARNING: invalid format '#{format}' (use 'xml' or 'json')" if format and not format[/(xml|json)/]
    serv.find(keyword, :format => format) {|x| print x}
  else
    $stderr.puts "ERROR: missing a keyword to search."
    $stderr.puts "> sparql.rb find keyword"
  end
when "head"
  if arguments.size > 2
    limit, offset, format, = *arguments
  elsif arguments.size > 1
    limit, offset, = *arguments
  elsif arguments.size > 0
    limit, = *arguments
  end
  opts = {
    :limit => limit,
    :offset => offset,
    :format => format,
  }
  serv.head(opts) {|x| print x}
when "help"
  help
  usage
else
  usage
end

end # Command line UI

