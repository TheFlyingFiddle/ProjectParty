using System;
using System.Collections.Generic;
using System.Drawing;
using System.IO;
using System.Linq;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using System.Windows.Forms;

namespace Logger
{
    interface ILogger
    {
        void logMessage(Color color, string id, string channel, string message);
    }
    
    class NetworkReceiver
    {
        private ILogger logger;
        private Color[] colorTable = new[] { Color.FromArgb(0xFF, 0, 0xaa, 0), Color.Orange, Color.Red };


        public NetworkReceiver(ILogger logger)
        {
            this.logger = logger;

            var thread = new Thread(() => ListenOnCllients(54321));
            thread.IsBackground = true;
            thread.Start();
        }

        private void ListenOnCllients(ushort port)
        {
            TcpListener listener = new TcpListener(new System.Net.IPEndPoint(IPExtensions.LocalIPAddress(), 0));
            listener.Start();

            LanBroadcaster.BroadcastPresence(((IPEndPoint)listener.LocalEndpoint).Address,
                                               ((IPEndPoint)listener.LocalEndpoint).Port);

            while (true)
            {
                var socket = listener.AcceptTcpClient();
                var thread = new Thread(() => ProcessLoggingMessages(socket));
                thread.IsBackground = true;
                thread.Start();
            }
        }

        private void ProcessLoggingMessages(TcpClient socket)
        {
            var reader = new BinaryReader(socket.GetStream());
            byte[] buffer = new byte[ushort.MaxValue];

            try
            {
                var tabNameLength = reader.ReadUInt16();
                reader.Read(buffer, 0, tabNameLength);
                //Ignore null terminator
                var tabName = Encoding.UTF8.GetString(buffer, 0, tabNameLength - 1);

                bool shouldProcess = true;
                while (shouldProcess)
                {
                    shouldProcess = ProcessMessage(reader, buffer, tabName);
                }

                logger.logMessage(Color.Gold, tabName, "Default", "Logging Finished!");
            }
            finally
            {
                socket.Close();
            }
        }
        
        private bool ProcessMessage(BinaryReader reader, byte[] buffer, string tabName)
        {
            try
            {
                var verbosity = reader.ReadByte();
                if (verbosity > colorTable.Length)
                {
                    throw new Exception("Invalid verbosity! verb= " + verbosity);
                }
                Color color = colorTable[verbosity];

                int len = reader.ReadUInt16();
                var read = 0;
                while (len != 0)
                {
                    var r = reader.Read(buffer, read, len);
                    read += r;
                    len -= r;
                }

                var message = Encoding.UTF8.GetString(buffer, 0, read);
                logger.logMessage(color, tabName, "Default", message);
            }
            catch (Exception e)
            {
                //Not much to do here. I think?
                logger.logMessage(Color.Red, tabName, "Default", "There was an error in the connection! " + e.Message);
                return false;
            }

            return true;
        }
    }
}
