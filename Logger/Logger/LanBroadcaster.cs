using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Net;
using System.Net.NetworkInformation;
using System.Net.Sockets;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace Logger
{
    class IPExtensions
    {
        public static IPAddress LocalIPAddress()
        {
            IPHostEntry host;
            host = Dns.GetHostEntry(Dns.GetHostName());
            foreach (IPAddress ip in host.AddressList)
            {
                if (ip.AddressFamily == AddressFamily.InterNetwork)
                {
                    return ip;
                }
            }

            throw new Exception("Failed to find local IP");
        }
    }

    class LanBroadcaster
    {
        const ushort servicePort = 34299;
        const string SERVICE_NAME = "LOGGING_SERVICE";

        private static IPAddress GetSubnetMask(IPAddress address)
        {
            foreach (NetworkInterface adapter in NetworkInterface.GetAllNetworkInterfaces())
            {
                foreach (UnicastIPAddressInformation unicastIPAddressInformation in adapter.GetIPProperties().UnicastAddresses)
                {
                    if (unicastIPAddressInformation.Address.AddressFamily == AddressFamily.InterNetwork)
                    {
                        if (address.Equals(unicastIPAddressInformation.Address))
                        {
                            return unicastIPAddressInformation.IPv4Mask;
                        }
                    }
                }
            }

            throw new ArgumentException(string.Format("Can't find subnetmask for IP address '{0}'", address));
        }

        private static IPAddress GetBroadcastAddress(IPAddress address, IPAddress subnetMask)
        {
            byte[] ipAdressBytes = address.GetAddressBytes();
            byte[] subnetMaskBytes = subnetMask.GetAddressBytes();

            if (ipAdressBytes.Length != subnetMaskBytes.Length)
                throw new ArgumentException("Lengths of IP address and subnet mask do not match.");

            byte[] broadcastAddress = new byte[ipAdressBytes.Length];
            for (int i = 0; i < broadcastAddress.Length; i++)
            {
                broadcastAddress[i] = (byte)(ipAdressBytes[i] | (subnetMaskBytes[i] ^ 255));
            }
            return new IPAddress(broadcastAddress);
        }

        private static IPAddress BroadcastAddress()
        {
            var ip = IPExtensions.LocalIPAddress();
            var mask = GetSubnetMask(ip);
            return GetBroadcastAddress(ip, mask);
        }

        public static void BroadcastPresence(IPAddress listenerAddress, int listenerPort)
        {
            var address = BroadcastAddress();
            var thread = new Thread(() =>
            {
                var socket = new Socket(AddressFamily.InterNetwork, SocketType.Dgram,
                                        ProtocolType.Udp);

                var receiveBuffer = new byte[256];
                var receiveStream = new MemoryStream(receiveBuffer);
                var reader        = new BinaryReader(receiveStream);

                socket.SetSocketOption(SocketOptionLevel.Socket, SocketOptionName.ReuseAddress, true);
                socket.Bind(new IPEndPoint(IPAddress.Any, servicePort));
                
                var stream = new MemoryStream(256);
                var writer = new BinaryWriter(stream);
                var utfName = Encoding.UTF8.GetBytes(SERVICE_NAME + '\0');
                writer.Write((ushort)utfName.Length);
                writer.Write(utfName);
                writer.Write(listenerAddress.GetAddressBytes()[3]);
                writer.Write(listenerAddress.GetAddressBytes()[2]);
                writer.Write(listenerAddress.GetAddressBytes()[1]);
                writer.Write(listenerAddress.GetAddressBytes()[0]);
                writer.Write((ushort)listenerPort);
                EndPoint ep = new IPEndPoint(0, 0);
                while (true)
                {
                    var buf = stream.GetBuffer();
                    //Receive service request
                    var received = socket.ReceiveFrom(receiveBuffer, ref ep);
                    receiveStream.SetLength(received);
                    var length = reader.ReadUInt16() - 1;
                    string s = Encoding.UTF8.GetString(receiveBuffer, 2, length);
                    receiveStream.Position = 0;

                
                    if (s == "LOGGING_SERVICE")
                    {
                        socket.SendTo(stream.GetBuffer(), (int)stream.Position, SocketFlags.None, ep);
                    }
                }
            });
            
            thread.IsBackground = true;
            thread.Start();
        }
    }
}
