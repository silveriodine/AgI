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
$tmpdir = nil
$outdir = Dir.getwd
$qcowback = nil
$qcowsize = nil
$printstyle = nil

def cleanup()
    FileUtils.rm_rf( $tmpdir )
end

def errexit(errmsg, exitcode = 1)
    $stderr.puts( errmsg )
    cleanup( )
    exit( exitcode )
end

def warn( errmsg )
    $stderr.puts( "Warning: #{errmsg}" )
end

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
    #set the disk resize size
    if inputhash['qcowsize']
	instancedata['qcowsize'] = inputhash['qcowsize']
    elsif
	instancedata['qcowsize'] = $qcowsize
    end
    #return the data
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

def goodqcowsize?( qcowsize )
    if qcowsize =~ /^[1-9][0-9.]*[MmGg]$/
	return true
    end
    return false
end

def goodoutdir?( possibledir )
    #determine if output dir is writable
    Dir.exist?( possibledir ) or errexit( "Specified path must be a directory." )
    File.writable?( possibledir ) or errexit( "Specified location must be writable." )
end

opts = GetoptLong.new( 
    [ '--help', '-h', GetoptLong::NO_ARGUMENT ],
    [ '--name', '-n', GetoptLong::REQUIRED_ARGUMENT ],
    [ '--count', '-c', GetoptLong::REQUIRED_ARGUMENT ],
    [ '--userdata', '-u', GetoptLong::REQUIRED_ARGUMENT ],
    [ '--directory', '-C', GetoptLong::REQUIRED_ARGUMENT ],
    [ '--disk', '-d', GetoptLong::REQUIRED_ARGUMENT ],
    [ '--size', '-s', GetoptLong::REQUIRED_ARGUMENT ],
    [ '--print', '-p', GetoptLong::OPTIONAL_ARGUMENT ]
)

opts.each { |option, value|
    case option
    when '--help'
	puts "usage: AgI.rb [OPTIONS] ... --name <INSTANCE> [OPTIONS] ... "
	puts "\t-n\n\t--name <instance>\tBase name for a group of instances"
	puts "\t-c\n\t--count <integer>\tNumber of a given instance to generate"
	puts "\t-u\n\t--userdata <file>\tCloud-init yaml configuration to supply\n\t\t\t\t
to a group of instances"
	puts "\t-C\n\t--directory <dir>\tDestination directory for generated files"
	puts "\t-d\n\t--disk <qcow2 img>\tDisk template to use as backing file for qcow clones"
	puts "\t-s\n\t--size <desired>\tResize the disk to a desired size. Problems will occur\n\t\t\t\t\
if the new size is smaller than the original."
	puts "\t-p\n\t--print [name[s]]\t\tDefine format of output, if any. 'name' is the default \
if no argument is specificied.\n\t\t\t\tFormat 'names' prints the instance name which files are prefixed with."
	exit 0
    when '--name'
	if String(value).length > 0
	    inputdata << { "name" => value }
	else
	    errexit( "Name must have a string of at least 1 character." )
	end
    when '--count'
	if inputdata.count > 0 and Integer( value ) > 0
	    inputdata[-1]['count'] = Integer( value )
	elsif Integer( value ) > 0
	    errexit( "Count must be a positive integer" )
	else
	    errexit( "Count must come after a --name arument" )
	end
    when '--userdata'
	if ! File.file?( value )
	    errexit( "Userdata must be path to a readable file." )
	end
	if inputdata.count > 0
	    inputdata[-1]['userdata'] = value
	else
	    $userdata = value
	end
    when '--directory'
	if ! goodoutdir?( value ) 
	    errexit( "Output directory must be a valid and writable." )
	end
	if inputdata.count > 0
	    inputdata[-1]['outdir'] = value
	else
	    $outdir = value
	end
    when '--disk'
	if ! goodqcow?( value )
	    errexit( "The file specified must be valid and QCOWv2 format" )
	end
	if inputdata.count > 0
	    inputdata[-1]['qcowback'] = value
	else
	    $qcowback = value
	end
    when '--print'
	if $printstyle != nil
	    warn("Output style is already set, the last instance of this flag will be set.")
	end
	if value == nil
	    $printstyle = "names"
	elsif value == "names" or value == "name"
	    $printstyle = "names"
	else
	    errexit( "Print output style is not valid" )
	end
    when '--size'
	if ! goodqcowsize?( value ) 
	    errexit( "Qcow resize must be in the form of a float or decimal with an M or G suffix" )
	end
	warn( "qcowsize is #{value}" )
	if inputdata[-1] 
	    inputdata[-1]['qcowsize'] = value
	elsif $qcowback 
	    $qcowsize = value
	end
	#warn( inputdata[-1]['qcowsize'] + " " + $qcowsize + ";" )
    end

}

#
#Check for a default userdata path and warn if unset
if ! $userdata
    warn( "No default userdata set. Please correct this if it's not intended." )
end

#
#determine if iso generation commands exist and save which it is.
if system( "which genisoimage > /dev/null 2>&1" )
    isogen="genisoimage"
elsif system( "which mkisofs > /dev/null 2>&1" )
    isogen="mkisofs"
else
    errexit( "System must have genisoimage or mkisofs installed in the current mode." )
end

if ! system( "which qemu-img > /dev/null 2>&1" )
    errexit( "System must have qemu-img in the environment PATH to clone QCOW2 disks." )
end

#convert input data into instance profiles
inputdata.each { | inputhash |
    #first set the name and generate the instance hash
    if inputhash['count'] == nil
	instances << geninstancedata( inputhash['name'], inputhash )
    elsif inputhash['count'] != nil
	for instancenum in 0..(inputhash['count'] - 1) 
	    instances << geninstancedata( inputhash['name'] + instancenum.to_s, inputhash )
	end
    else
	errexit( "I don't know how you got here. I'm impressed." )
    end
}   

#create a temporary directory to write 
$tmpdir = Dir.mktmpdir or errexit( "Directory /tmp must be writable by the current user." )

#main loop - generates meta-data, copies includes, and creates ISOs
instances.each { | instancecur |
    FileUtils.rm_rf( "#{$tmpdir}/*" )
    instancefile = File.new("#{$tmpdir}/meta-data","w")
    instancefile.write( instancecur['metadata'].to_yaml )
    instancefile.close
    if instanceuserdata = instancecur['user-data'] or instanceuserdata = $userdata
	FileUtils.cp( instanceuserdata, "#{$tmpdir}/user-data" ) 
    #else 
	#errexit( "Must be able to copy \"#{instanceuserdata}\" to \"#{$tmpdir}\"." )
    end

    #ISO generation block
    if system( "#{isogen} -output #{instancecur['outdir']}/#{instancecur['metadata']['instance-id']}.iso \
-volid cidata -joliet -rock #{$tmpdir}/* > /dev/null 2>&1" )
	#$stderr.puts "ISO generation for \"#{instancecur['metadata']['instance-id']}\" successful!"
    else
	errexit( "Failure during ISO generation for \"#{instancecur['metadata']['instance-id']}\"!" )
    end

    #QCOW generation block. If qcowback is nil, we do nothing. Otherwise we proceed throug the routine
    if ! instancecur['qcowback']
    elsif system( "qemu-img create -q -f qcow2 -o backing_file=#{instancecur['qcowback']} \
#{instancecur['outdir']}/#{instancecur['metadata']['instance-id']}.qcow2 #{instancecur['qcowsize']}" )
	#$stderr.puts "QCOW2 generation for \"#{instancecur['metadata']['instance-id']}\ at size \"#{instancecur['qcowsize']}\" successful!"
    else
	errexit( "Failure during QCOW2 disk generation for \"#{instancecur['metadata']['instance-id']}\"" )
    end
    
    if $printstyle == 'names'
	puts( instancecur['metadata']['instance-id'] )
    end
}

#cleanup
cleanup( )

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
#DONE warn aboout any unset default userdata
#RM'd name dir after instance id.
#DONE name iso after instance id.
#DONE alternate output directory
#DONE set up instance specific userdata
#DONE set up qcow2 backed-cloning
#DONE create error message and exit function.
#DONE create cleanup function 
#DONE print each instance name for scripting purposes.
#TODO add another usage example to README using every flag available
#DONE add example scripted loop with qemu and --print name
#DONE add argument to resize qcow disks to a new size.
#TODO Add a basic userdata file that sets an unencrypted password and adds a dummy ssh key.
