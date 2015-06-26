#!/usr/bin/ruby -w 


require 'fileutils'
require 'getoptlong'
require 'tmpdir'
require 'yaml'

# Main variables that carry data through the script.
# Declaring because habit
inputdata = [ ]
instances = [ ]
userdata = nil
isogen = nil
tmpdir = nil
outdir = Dir.getwd

def genmetadata( id )
    md = Hash.new
    md['instance-id'] = id
    md['local-hostname'] = id.downcase
    return md
end

opts = GetoptLong.new( 
    [ '--help', '-h', GetoptLong::NO_ARGUMENT ],
    [ '--name', '-n', GetoptLong::REQUIRED_ARGUMENT ],
    [ '--count', '-c', GetoptLong::REQUIRED_ARGUMENT ],
    [ '--userdata', '-u', GetoptLong::REQUIRED_ARGUMENT ],
    [ '--directory', '-C', GetoptLong::REQUIRED_ARGUMENT ]
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
	if inputdata.count > 0 and Integer( value ) > 0
	    inputdata[-1]['count']=Integer( value )
	elsif inputdata.count > 0
	    raise "Count must be a positive integer"
	else
	    raise "Count must come after a --name arument"
	end
    when '--userdata'
	if File.file?( value )
	    userdata = value
	else
	    raise "Userdata must be path to a readable file."
	end
    when '--directory'
	outdir = value
    end
}

#
#determine if iso generation commands exist and save which it is.
if system( "which genisoimage > /dev/null 2>&1" )
    isogen="genisoimage"
elsif system( "which mkisofs > /dev/null 2>&1" )
    isogen="mkisofs"
else
    raise "System must have genisoimage or mkisofs installed in the current mode."
end

#determine if output dir is writable
Dir.exist?( outdir ) or raise "Specified path must be a directory."
File.writable?( outdir ) or raise "Specified location must be writable."

inputdata.each { | inputhash |
    if inputhash['count'] == nil
	instances << genmetadata(inputhash['name'])
    elsif inputhash['count'] != nil
	for instancenum in 0..(inputhash['count'] - 1) 
	    instances << genmetadata( inputhash['name'] + instancenum.to_s )
	end
    else
	raise "I don't know how you got here. I'm impressed."
    end
}    

#create a temporary directory to write 
tmpdir = Dir.mktmpdir or raise "Directory /tmp must be writable by the current user."

#main loop - generates meta-data, copies includes, and creates ISOs
instances.each { | instancecur |
    instancefile = File.new("#{tmpdir}/meta-data","w")
    instancefile.write( instancecur.to_yaml )
    instancefile.close
    if instanceuserdata = instancecur['user-data'] or instanceuserdata = userdata
	FileUtils.cp( instanceuserdata, "#{tmpdir}/user-data" ) 
    else 
	raise "Must be able to copy #{instanceuserdata} to #{tmpdir}."
    end

    if system( "#{isogen} -output #{outdir}/#{instancecur['instance-id']}.iso -volid cidata -joliet -rock #{tmpdir}/* > /dev/null 2>&1" )
	$stderr.puts "ISO generation for #{instancecur['instance-id']} successful!"
    else
	raise "Failure during ISO generation for #{instancecur['instance-id']}!"
    end
}

FileUtils.rm_rf( tmpdir )

#debug output
#puts inputdata
#puts " ----- "
#puts instances
#
#DONE create array of hashes for names and counts. 
#DONE change 'instances' to 'input'
#DONE detect whether genisoimage/mkisofs otherwise error out and advise the use of directories.
#DONE take userdata input file and include in all inputdata
#TODO ?defaults input before any --name parameters
#TODO name dir after instance id.
#DONE name iso after instance id.
#DONE alternate output directory
#DONE set up instance specific userdata
#TODO set up qcow2 backed-cloning
#
