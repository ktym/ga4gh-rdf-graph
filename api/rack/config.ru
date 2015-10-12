require 'rubygems'
require 'handlebars'         # gem install handlebars
require 'sinatra'            # gem install sinatra
require 'sinatra/base'
require 'sinatra/streaming'  # gem install sinatra-contrib
require 'rack'               # gem install rack
require 'json'               # gem install json
load 'sparql.rb'

class Ga4ghApi < Sinatra::Base

  API_VERSION = "v0.6.g"
  #GRAPH_NAME = "camel-mhc"
  GRAPH_NAME = "camel-brca1"
  SPARQL_ENDPOINT = "http://ep.dbcls.jp/sparql71tmp"

  @@endpoint = SPARQL.new(SPARQL_ENDPOINT)
  @@handlebars = Handlebars::Context.new

  def sparql_query(template, config)
    result = ""
    sparql = @@handlebars.compile(template).call(config)
    @@endpoint.query(sparql, :format => 'json') { |x|
      result << x
    }
    return result
  end

  get '/' do
    help = <<-HELP
      GA4GH SPARQL version of the reference genome graph server v20151013 (DWG-NYC-Hackathon)
      <pre>
Protocol version #{API_VERSION}

Operations available

Method	   Path
POST	   /#{API_VERSION}/allelecalls/search
GET	   /#{API_VERSION}/alleles/<id>
POST	   /#{API_VERSION}/alleles/search
POST	   /#{API_VERSION}/callsets/search
POST	   /#{API_VERSION}/joins/search
GET	   /#{API_VERSION}/mode/<mode>
POST	   /#{API_VERSION}/readgroupsets/search
POST	   /#{API_VERSION}/reads/search
GET	   /#{API_VERSION}/references/<id>
GET	   /#{API_VERSION}/references/<id>/bases
POST	   /#{API_VERSION}/references/search
GET	   /#{API_VERSION}/referencesets/<id>
POST	   /#{API_VERSION}/referencesets/search
GET	   /#{API_VERSION}/sequences/<id>/bases
POST	   /#{API_VERSION}/sequences/search
POST	   /#{API_VERSION}/subgraph/extract
POST	   /#{API_VERSION}/variants/search
POST	   /#{API_VERSION}/variantsets/search
      </pre>
    HELP
  end

  get "/#{API_VERSION}/alleles/:alleleID" do
    template = File.read("sparql/get_alleles.rq")
    config = {
      :graph => GRAPH_NAME,
      :alleleID => "Allele/#{params[:alleleID]}",
    }
    return sparql_query(template, config)
  end

end

run Ga4ghApi


