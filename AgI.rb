#!/usr/bin/ruby -w 

require 'fileutils'
require 'getoptlong'
require 'tmpdir'
require 'yaml'

# Main variables that carry data through the script.
# Declaring because habit
inputdata = [ ]
instances = [ ]
$userdata = nil
isogen = nil
tmpdir = nil
$outdir = Dir.getwd
$qcowback = nil

def genmetadata( id )
    md = Hash.new
    md['instance-id'] = id
    md['local-hostname'] = id.downcase
    return md
end

def geninstancedata( id, inputhash )
    instancedata = Hash['metadata', genmetadata( id )]
    #now we set the userdata
    if inputhash['userdata']
	instancedata['userdata'] = inputhash['userdata']
    elsif $userdata
	instancedata['userdata'] = $userdata
    end
    #set the output directory 
    if inputhash['outdir']
	instancedata['outdir'] = inputhash['outdir']
    else
	instancedata['outdir'] = $outdir
    end
    #set the disk gen
    if inputhash['qcowback']
	instancedata['qcowback'] = inputhash['qcowback']
    elsif $qcowback
	instancedata['qcowback'] = $qcowback
    end
    return instancedata
end

def goodqcow?( qcowfile )
    if File.exist?( qcowfile ) && system( "which file > /dev/null 2>&1" )
	fileout = %x[ file "#{qcowfile}" ]
	return fileout.include?( "QEMU QCOW Image (v2)" )
    else
	return False
    end
end

def goodoutdir?( possibledir )
    #determine if output dir is writable
    Dir.exist?( possibledir ) or raise "Specified path must be a directory."
    File.writable?( possibledir ) or raise "Specified location must be writable."
end

opts = GetoptLong.new( 
    [ '--help', '-h', GetoptLong::NO_ARGUMENT ],
    [ '--name', '-n', GetoptLong::REQUIRED_ARGUMENT ],
    [ '--count', '-c', GetoptLong::REQUIRED_ARGUMENT ],
    [ '--userdata', '-u', GetoptLong::REQUIRED_ARGUMENT ],
    [ '--directory', '-C', GetoptLong::REQUIRED_ARGUMENT ],
    [ '--disk', '-d', GetoptLong::REQUIRED_ARGUMENT ]
)

opts.each { |option, value|
    case option
    when '--help'
	puts "usage: AgI.rb [OPTIONS] ... --name <INSTANCE> [OPTIONS] ... "
	puts "\t-n\n\t--name <instance>\tBase name for a group of instances"
	puts "\t-c\n\t--count <integer>\tNumber of a given instance to generate"
	puts "\t-u\n\t--userdata <file>\tCloud-init yaml configuration to supply\n\t\t\t\tto a group of instances"
	puts "\t-C\n\t--directory <dir>\tDestination directory for generated files"
	exit 0
    when '--name'
	if String(value).length > 0
	    inputdata << { "name" => value }
	else
	    raise "Name must have a string of at least 1 character."
	end
    when '--count'
	if inputdata.count > 0 and Integer( value ) > 0
	    inputdata[-1]['count'] = Integer( value )
	elsif Integer( value ) > 0
	    raise "Count must be a positive integer"
	else
	    raise "Count must come after a --name arument"
	end
    when '--userdata'
	if ! File.file?( value )
	    raise "Userdata must be path to a readable file."
	end
	if inputdata.count > 0
	    inputdata[-1]['userdata'] = value
	else
	    $userdata = value
	end
    when '--directory'
	if ! goodoutdir?( value ) 
	    raise "Output directory must be a valid and writable."
	end
	if inputdata.count > 0
	    inputdata[-1]['outdir'] = value
	else
	    $outdir = value
	end
    when '--disk'
	if ! goodqcow?( value )
	    raise "The file specified must be valid and QCOWv2 format"
	end
	if inputdata.count > 0
	    inputdata[-1]['qcowback'] = value
	else
	    $qcowback = value
	end
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

if ! system( "which qemu-img > /dev/null 2>&1" )
    raise "System must have qemu-img in the environment PATH to clone QCOW2 disks."
end

#convert input data into instance profiles
inputdata.each { | inputhash |
    #first set the name and generate the instance hash
    if inputhash['count'] == nil
	instances << geninstancedata( inputhash['name'], inputhash )
    elsif inputhash['count'] != nil
	for instancenum in 0..(inputhash['count'] - 1) 
	    instances << geninstancedata( inputhash['name'] + instancenum.to_s, inputhash)
	end
    else
	raise "I don't know how you got here. I'm impressed."
    end
}   

#create a temporary directory to write 
tmpdir = Dir.mktmpdir or raise "Directory /tmp must be writable by the current user."

#main loop - generates meta-data, copies includes, and creates ISOs
instances.each { | instancecur |
    FileUtils.rm_rf( "#{tmpdir}/*" )
    instancefile = File.new("#{tmpdir}/meta-data","w")
    instancefile.write( instancecur['metadata'].to_yaml )
    instancefile.close
    if instanceuserdata = instancecur['user-data'] or instanceuserdata = $userdata
	FileUtils.cp( instanceuserdata, "#{tmpdir}/user-data" ) 
    else 
	raise "Must be able to copy #{instanceuserdata} to #{tmpdir}."
    end

    if system( "#{isogen} -output #{$outdir}/#{instancecur['metadata']['instance-id']}.iso -volid cidata -joliet -rock #{tmpdir}/* > /dev/null 2>&1" )
	$stderr.puts "ISO generation for #{instancecur['metadata']['instance-id']} successful!"
    else
	raise "Failure during ISO generation for #{instancecur['instance-id']}!"
    end
}

#cleanup
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
#DONE ?defaults input before any --name parameters
#DONE restructure getopt loop to handle default & override configurations.
#TODO warn aboout any unset default userdata
#TODO name dir after instance id.
#DONE name iso after instance id.
#DONE alternate output directory
#DONE set up instance specific userdata
#TODO set up qcow2 backed-cloning
#TODO create error message and exit function.
#TODO create cleanup function 
#
