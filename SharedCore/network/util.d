module network.util;

import std.socket;
import allocation;

string localIPString()
{
	auto addresses = getAddress(Socket.hostName);
	foreach(Address address; addresses)
	{
		if(address.addressFamily == AddressFamily.INET) {
			return address.toAddrString();
		}
	}

	assert(0, "Failed to locate local address!");
}

InternetAddress lanBroadcastAddress(A)(ref A allocator, ushort port)
{
	InternetAddress tmp = GlobalAllocator.allocate!InternetAddress(localIPString, port);
	scope(exit) GlobalAllocator.deallocate(tmp);

	auto broadcastIp = tmp.addr | 0xFF;
	return allocator.allocate!InternetAddress(broadcastIp, port);
}