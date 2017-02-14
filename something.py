import boto.route53
import re
from subprocess import call, check_output
import argparse

parser = argparse.ArgumentParser(description=
        '')
parser.add_argument('-h', '--host-info',required=False, help='get info about host env')
parser.add_argument('-s', '--source_file',required=True, type=lambda x: is_file(parser, x) , help=' source file location')

args = parser.parse_args()

conn=boto.route53.connect_to_region("us-east-1")
z = conn.get_zone("ecs.internal.")
record_set = z.get_records() # list
#dbz_cnames =  [y for y in record_set if bool(re.search(u'^dbz-\d+.*', y.name))]
 
p = re.compile(u'^dbz-(\d+).*')
# [item for sublist in [p.findall(y.name) for y in x if bool(p.search( y.name))] for item in sublist]

# list of tuples - (BROKER_ID, dns-name, server-ip)
[(p.search(y.name).groups()[0], y.name, check_output(['getent','hosts', y.name]).split(" ")[0].decode('utf-8')) for y in z.get_records() if bool(p.search( y.name))]
#host_ip = check_output(['getent','hosts', servers[0][1]])
host_ip = check_output(['curl', 'http://169.254.169.254/latest/meta-data/local-ipv4'])

### if just getting our box info
my_server = [server for server in servers if server[2] == host_ip.decode('utf-8')][0]
print "BROKER_ID=%s" % my_server[0]
print "SERVER_ID=%s" % my_server[0]
print "MY_DNS_HOST_NAME=%s" % my_server[1]
print "MY_HOST_IP=%s" % my_server[2]

for server in servers:
### todo - assign ports dynamically
    print "server.%s=%s:%s:%s" % ( server[0], server[1], "2888", "3888")
