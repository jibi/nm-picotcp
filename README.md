# Getting Started with Netmap and PicoTCP

### Netmap
[Netmap](http://info.iet.unipi.it/~luigi/netmap/) is a framework for high speed
packet IO.
This framework allows to map the NIC packet rings directly in user space,
permitting an application to handle raw packets with zero cost of copying/moving
data between kernel and user space. Moreover, it allows to reduce the context
switch cost: in fact, it is possible to receive and send multiple packets with
just one system call.

### PicoTCP
[PicoTCP](http://github.com/tass-belgium/picotcp) is a tiny but complete TCP/IP
stack designed for embedded devices, which runs in user space.

### Architecture
This example tries to show how to use Netmap and PicoTCP to implement a basic
TCP echo server. Netmap is used to define a custom PicoTCP device (which in turn
will be used to read and write packets). PicoTCP is used to provide a userspace
TCP/IP stack and to implement the echo server logic (i.e. read from a socket and
send back data).

## Compile and run the example

To compile the code first clone this repository and its dependencies
```
$ git clone --recursive git@github.com:jibi/nm-picotcp.git
```
then cd into the repository and compile the dependencies
```
$ cd nm-picotcp
$ make deps
```
you will need the base development packages (make, gcc, ..) and the kernel headers.

After that, build the example with
```
$ make
```
load the netmap module
```
$ su
# insmod deps/netmap/LINUX/netmap_lin.ko
```
bring up the interface you want to use
```
# ifconfig $if
```
and start the example
```
# ./picotcp_netmap $if $mac $ip $port
```
where

* `$if` is the network interface
* `$mac` is the real mac of the network interface
* `$ip` is the ip you want the interface to use
* `$port` is the TCP port you want the server to listen to

if you do not want to use the real mac of the network interface, you need to set the card in promisc mode
```
# ifconfig $if promisc
```
Now you can test the echo server from another machine (because at the moment
Netmap does not seem to work with host rings) with
```
telnet $ip $port
```

## Code Walkthrough

### init_picotcp
This function initializes the PicoTCP stack with `pico_stack_init`, creates a
`pico_device` with `pico_netmap_create` and assignes an address to the device
with `pico_ipv4_link_add`.

### pico_netmap_create
This function creates a new PicoTCP device, which is a descriptor used to read
and write data from the network. It is composed of the `pico_device` field, which
is the struct that PicoTCP actually uses, plus some other fields that are needed
for the specific device.

PicoTCP provides some default devices for common usages such as
`pico_device_loop`, `pico_device_pcap` or `pico_device_tun`.

Since the application needs to use Netmap, following the other devices
implementation, a custom one named `pico_device_netmap` has been defined.

This struct contains a `pico_device` struct named dev and a `nm_desc` struct, which
is the Netmap descriptor.

After allocating and initializing the pico device with `pico_device_init`, the
Netmap descriptor is initialized with `nm_open`.

Eventually the `send` and `poll` function pointers of the pico device struct
are initialized. These functions will be called when PicoTCP needs to send and
receive data from the network.

### pico_netmap_send
This function is called each time PicoTCP needs to send a packet. It just gets
the Netmap descriptor and it calls `nm_inject` with the packet buffer and its
length.

### pico_netmap_poll
This function is called each time PicoTCP needs to ask the network interface
whether there are packets to receive.

Netmap uses the `poll` syscall on his control file descriptor to check for data
availability and since `pico_netmap_poll` must be nonblocking, poll is called with a
timeout of -1.
If it returns something greater than 0 the function `nm_dispatch`
is called, which in turn calls the `pico_dev_netmap_cb` on every packet received.

This function just calls `pico_stack_recv` with the packet buffer and length, to
deliver the packet to the PicoTCP stack.

### setup_tcp_app
This function initializes the TCP application.
First it creates a socket with `pico_socket_open` and binds it to the right
address and port with `pico_socket_bind`. Then it starts listening for
connections on the socket with `pico_socket_listen`.

The application logic is implemented as a callback (`cb_tcpecho`) which is passed
to `pico_socket_open`.

### cb_tcpecho
This function implements the actions that will be taken when some events occour:

* when the socket needs to handle a new connection, the event `PICO_SOCK_EV_CONN`
  is signaled and the connection is accepted with `pico_socket_accept`

* when the socket needs to receive data, the event `PICO_SOCK_EV_RD` is signaled
  and the function `pico_socket_read` is used to read data from the TCP stream

* when the events `PICO_SOCK_EV_WR` is launched, the application knows that it is
  possible to send data using `pico_sock_write`. When the application needs to
  send data, it should
  * enqueue data in some way (in this case the example uses a simple array buffer)
  * try to send immediatly data, keeping track of how many bytes are sent
  * send the remaining data after the `PICO_SOCK_EV_WR` event is launched

## Alternatives

In case the application needs an userspace TCP/IP stack but does not need extreme
performance, it is possible to replace Netmap with libpcap or VDE. The advantage
is that there is no need to compile and load an external module.

To change the device it is sufficient to replace the `pico_device_netmap` with
the correct one and call its initialization function.

For example, to use libpcap you just need to replace the call to
`pico_netmap_create` with a call to `pico_pcap_create_live`, since the two
functions take the same parameters.
