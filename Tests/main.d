import std.stdio;


struct OutgoingNetworkMessage
{
	ubyte id;
}

alias Out = OutgoingNetworkMessage;
enum Outgoing : OutgoingNetworkMessage 
{
	transaction = Out(50),
	bla		    = Out(51),
	bur			= Out(52)
}

void main()
{
	static assert(OutgoingNetworkMessage(50) == Outgoing.transaction);
	static assert(Outgoing.transaction == __traits(getAttributes, Transaction)[0]);
}

@(Outgoing.transaction) struct Transaction
{

}
