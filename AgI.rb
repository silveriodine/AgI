#!/usr/bin/ruby -w 


require 'getoptlong'
require 'yaml'

inputdata = []
instances = []
userdata = nil

def genmetadata(id)
    md = Hash.new
    md['instance-id'] = id
    md['hostname'] = id.downcase
    return md
end

opts = GetoptLong.new( 
    [ '--help', '-h', GetoptLong::NO_ARGUMENT ],
    [ '--name', '-n', GetoptLong::REQUIRED_ARGUMENT ],
    [ '--count', '-c', GetoptLong::REQUIRED_ARGUMENT ],
    [ '--userdata', '-u', GetoptLong::REQUIRED_ARGUMENT ]
)

opts.each { |option, value|
    case option
    when '--name'
	if String(value).length > 0
	    inputdata << { "name" => value }
	else
	    raise "Name must have a string of at least 1 character."
	end
    when '--count'
	if inputdata.count > 0 and Integer(value) > 0
	    inputdata[-1]['count']=Integer(value)
	elsif inputdata.count > 0
	    raise "Count must be a positive integer"
	else
	    raise "Count must come after a --name arument"
	end
    when '--userdata'
	if File.file?(value)
	    userdata = value
	else
	    raise "Userdata must be path to a readable file."
	end
    end
}

#
#determine if iso generation commands exist and save which it is.
if system("which genisoimage > /dev/null 2>&1")
    isogen="genisoimage"
elsif system("which mkisofs > /dev/null 2>&1")
    isogen="mkisofs"
else
    raise "System must have genisoimage or mkisofs installed in the current mode."
end

inputdata.each { | inputhash |
    if inputhash['count'] == nil
	instances << genmetadata(inputhash['name'])
    elsif inputhash['count'] != nil
	for instancenum in 0..(inputhash['count'] - 1) 
	    instances << genmetadata(inputhash['name'] + instancenum.to_s)
	end
    else
	raise "I don't know how you got here. I'm impressed."
    end
}    

#debug output
puts inputdata
puts " ----- "
puts instances
#DONE create array of hashes for names and counts. 
#DONE change 'instances' to 'input'
#DONE detect whether genisoimage/mkisofs otherwise error out and advise the use of directories.
#take userdata input file and include in all inputdata
#?defaults input before any --name parameters
#name iso/dir after instance id.
#
