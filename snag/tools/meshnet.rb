#!/usr/bin/env ruby

require 'rubygems'
require 'neography'

def create_person(name)
  Neography::Node.create("name" => name)
end
 
johnathan = create_person('Johnathan')
mark      = create_person('Mark')
phil      = create_person('Phil')
mary      = create_person('Mary')
luke      = create_person('Luke')
 
johnathan.both(:friends) << mark
mark.both(:friends) << mary
mark.both(:friends) << phil
phil.both(:friends) << mary
phil.both(:friends) << luke
 
def suggestions_for(node)
  node.incoming(:friends).
       order("breadth first").
       uniqueness("node global").
       filter("position.length() == 2;").
       depth(2).
       map{|n| n.name }.join(', ')
end
puts "Johnathan should become friends with #{suggestions_for(johnathan)}"
 
# RESULT
# Johnathan should become friends with Mary, Phil

def generate_text(length=8)
  chars = 'abcdefghjkmnpqrstuvwxyz'
  name = ''
  length.times { |i| name << chars[rand(chars.length)] }
  name
end
def create_graph
  neo = Neography::Rest.new
  graph_exists = neo.get_node_properties(1)
  return if graph_exists && graph_exists['name']
 
  names = 200.times.collect{|x| generate_text}
 
  commands = names.map{ |n| [:create_node, {"name" => n}]}
  names.each_index do |x| 
    follows = names.size.times.map{|y| y}
    follows.delete_at(x)
    follows.sample(rand(10)).each do |f|
      commands << [:create_relationship, "follows", "{#{x}}", "{#{f}}"]    
    end
  end
 
  batch_result = neo.batch *commands
end
def follower_matrix
  neo = Neography::Rest.new
  cypher_query =  " START me = node({node_id})"
  cypher_query << " MATCH (me)-[?:follows]->(friends)-[?:follows]->(fof)-[?:follows]->(fofof)-[?:follows]->others"
  cypher_query << " RETURN me.name, friends.name, fof.name, fofof.name, count(others)"
  cypher_query << " ORDER BY friends.name, fof.name, fofof.name, count(others) DESC"
  neo.execute_query(cypher_query, {:node_id => 1 + rand(200)})["data"]
end 

get '/followers' do
  data = follower_matrix.inject({}) {|h,i| t = h; i.each {|n| t[n] ||= {}; t = t[n]}; h}
  with_children(data).to_json
end

def with_children(node)
  if node[node.keys.first].keys.first.is_a?(Integer)
    { "name" => node.keys.first,
      "size" => 1 + node[node.keys.first].keys.first 
     }
  else
    { "name" => node.keys.first, 
      "children" => node[node.keys.first].collect { |c| 
        with_children(Hash[c[0], c[1]]) } 
    }
  end
end

var colorscale = d3.scale.category10();
 
function color(d) {
  return d._children ? "#3182bd" : d.children ? "#c6dbef" : colorscale(d.size);
}

