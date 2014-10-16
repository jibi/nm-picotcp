CC=gcc
CFLAGS=-c -Wall -Wextra -Os -I deps/picotcp/build/include -I deps/netmap/sys
LDFLAGS=-L deps/picotcp/build/lib -lpicotcp
SOURCES=nm-picotcp.c
OBJECTS=$(SOURCES:.c=.o)
EXECUTABLE=nm-picotcp

$(EXECUTABLE): $(OBJECTS)
	$(CC) $(OBJECTS) $(LDFLAGS) -o $@

.c.o:
	$(CC) $(CFLAGS) $< -o $@

all: $(SOURCES) $(EXECUTABLE)

deps: deps/picotcp deps/netmap
	cd deps/picotcp;      make IPV6=0 NAT=0 MCAST=0 IPFILTER=0 DNS_CLIENT=0 SNTP_CLIENT=0 DHCP_CLIENT=0 DHCP_SERVER=0 HTTP_CLIENT=0 HTTP_SERVER=0 OLSR=0 SLAACV4=0 IPFRAG=0 DEBUG=0
	cd deps/netmap/LINUX; make NODRIVERS=1

clean:
	@rm $(EXECUTABLE)
	@rm $(OBJECTS)

depsclean:
	cd deps/picotcp;      make clean
	cd deps/netmap/LINUX; make clean
