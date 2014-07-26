using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Drawing;
using System.IO;
using System.Linq;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using System.Windows.Forms;

namespace Lua_Console
{
    public partial class Form1 : Form, IView
    {
        public Form1()
        {
            InitializeComponent();
            new NetworkReceiver(this);
        }

        private void addControl(Control control, TabPage page)
        {
            control.Size = tabControl.TabPages[0].Size;
            control.Anchor = AnchorStyles.Bottom | AnchorStyles.Left | AnchorStyles.Right | AnchorStyles.Top;

            page.Controls.Add(control);
        }

        private TabPage pageWithText(string text)
        {
            for (int i = 0; i < tabControl.TabPages.Count; i++)
            {
                var page = tabControl.TabPages[i];
                if (page.Text == text) return page;
            }

            return null;
        }

        private void connectedImpl(string id, ConnectionType type, IRemoteConnection connection)
        {
            var page = pageWithText(id);
            if (page != null)
            {
                var t_id = page.Text;
                if (t_id == id)
                {
                    if (((ConnectionType)page.Tag) == type)
                    {
                        if (type == ConnectionType.luaDebug)
                        {
                            var ctrl = page.Controls[0] as LuaConsole;
                            ctrl.connection = connection;
                        }
                        return;
                    }
                    else
                    {
                        tabControl.TabPages.Remove(page);
                    }
                }
            }

            var t_page = new TabPage(id);
            t_page.Tag = type;
            t_page.ImageKey = id;

            tabControl.TabPages.Add(t_page);

            if (type == ConnectionType.logger)
                addControl(new LoggingControl(), t_page);
            else if (type == ConnectionType.luaDebug)
                addControl(new LuaConsole(connection), t_page);
            else
                throw new Exception("Unable to connect to the connectionType: " + type);
        }

        private void logMessageImpl(Color color, string id, string channel, string message)
        {
            var page = pageWithText(id);
            var logger = page.Controls[0] as ILogView;
            if (logger != null)
            {
                logger.logMessage(color, channel, message);
            }
        }

        private void consoleResultImpl(Color color, string id, string result)
        {
            var page = pageWithText(id);
            var console = page.Controls[0] as ILuaConsole;
            if (console != null)
            {
                console.consoleResult(color, result);
            }
        }
                
        public void connected(string id, ConnectionType type, IRemoteConnection con)
        {
            tabControl.Invoke((Action)(() => connectedImpl(id, type, con)));
        }

        public void logMessage(Color color, string id, string channel, string message)
        {
            tabControl.Invoke((Action)(() => logMessageImpl(color, id, channel, message)));

        }

        public void consoleResult(Color color, string id, string result)
        {
            tabControl.Invoke((Action)(() => consoleResultImpl(color, id, result)));
        }
    }

    public interface IRemoteConnection
    {
        event Action onTermination;
        void sendConsoleInput(string input);
    }

    interface ILogView
    {
        void logMessage(Color color, string channel, string message);
    }

    interface ILuaConsole
    {
        void consoleResult(Color color, string result);
    }

    interface IView
    {
        void connected(string id, ConnectionType type, IRemoteConnection connection);
        void logMessage(Color color, string id, string channel, string message);
        void consoleResult(Color color, string id, string result);
    }

    public enum ConnectionType
    {
        logger = 0, 
        luaDebug = 1
    }

    enum NetworkCommand
    {
        log = 0,
        validConsoleResult = 1,
        invalidConsoleResult = 2
    }

    class NetworkReceiver
    {
        private IView view;

        private Color[] colorTable = new[] { Color.FromArgb(0xFF, 0, 0xaa, 0), Color.Orange, Color.Red };


        public NetworkReceiver(IView view)
        {
            this.view = view;

            var thread = new Thread(() => ListenOnCllients(54321));
            thread.IsBackground = true;
            thread.Start();
        }

        private void ListenOnCllients(ushort port)
        {
            TcpListener listener = new TcpListener(new System.Net.IPEndPoint(IPExtensions.LocalIPAddress(), 0));
            listener.Start(1);

            LanBroadcaster.BroadcastPresence(((IPEndPoint)listener.LocalEndpoint).Address,
                                               ((IPEndPoint)listener.LocalEndpoint).Port);

            while (true)
            {
                var socket = listener.AcceptTcpClient();
                socket.Client.SetSocketOption(SocketOptionLevel.Tcp, SocketOptionName.NoDelay, 1);
                var thread = new Thread(() => ProcessLoggingMessages(socket));
                thread.IsBackground = true;
                thread.Start();
            }
        }

        private class RemoteConsole : IRemoteConnection
        {
            BinaryWriter writer;

            public RemoteConsole(BinaryWriter writer) { this.writer = writer; }

            public void sendConsoleInput(string input)
            {
                byte[] toSend = Encoding.UTF8.GetBytes(input + "\0");

                writer.Write((ushort)toSend.Length);
                writer.Write(toSend);

                writer.Flush();
            }

            public void invoke()
            {
                onTermination();
            }

            public event Action onTermination;
        }


        private void ProcessLoggingMessages(TcpClient socket)
        {
            var reader = new BinaryReader(socket.GetStream());
            byte[] buffer = new byte[ushort.MaxValue];

            RemoteConsole con = null;
            try
            {
                var conType = reader.ReadByte();
                var tabNameLength = reader.ReadUInt16();
                reader.Read(buffer, 0, tabNameLength);
                var tabName = Encoding.UTF8.GetString(buffer, 0, tabNameLength - 1);

                if ((ConnectionType)conType == ConnectionType.luaDebug)
                    con = new RemoteConsole(new BinaryWriter(socket.GetStream()));

                view.connected(tabName, (ConnectionType)conType, con);

                view.logMessage(Color.White, tabName, "Connection", "Connection established: "
                                + socket.Client.RemoteEndPoint + " - " + tabName);

                bool shouldProcess = true;
                while (shouldProcess)
                {
                    shouldProcess = ProcessMessage(reader, buffer, tabName);
                }

                view.logMessage(Color.Gold, tabName, "Default", "Logging Finished!");
            }
            catch (Exception e)
            {
                MessageBox.Show(e.Message);
            }
            finally
            {
                socket.Close();
                if(con != null)
                    con.invoke();
            }
        }

        private bool ProcessMessage(BinaryReader reader, byte[] buffer, string id)
        {
            try
            {
                var commandType = reader.ReadByte();
                switch ((NetworkCommand)commandType)
                {
                    case NetworkCommand.log:
                        ProcessLogMessage(reader, buffer, id);
                        break;
                    case NetworkCommand.validConsoleResult:
                        ProcessValidConsoleResult(reader, buffer, id);                    
                        break;
                    case NetworkCommand.invalidConsoleResult:
                        ProcessInvalidConsoleResult(reader, buffer, id);
                        break;
                    default:
                        throw new Exception("Got unrecognized command: " + commandType);
                }
                
         }
            catch (Exception e)
            {
                //Not much to do here. I think?
                view.logMessage(Color.Red, id, "Default", "There was an error in the connection! " + e.Message);
                return false;
            }

            return true;
        }

        private string readString(BinaryReader reader, byte[] buffer)
        {
            int len = reader.ReadUInt16();
            var read = 0;
            while (len != 0)
            {
                var r = reader.Read(buffer, read, len);
                read += r;
                len -= r;
            }
            //-1 since we don't care about the '\0' symbol here!
            return Encoding.UTF8.GetString(buffer, 0, read - 1);
        }

        private void ProcessInvalidConsoleResult(BinaryReader reader, byte[] buffer, string id)
        {
            view.consoleResult(Color.Red, id, readString(reader, buffer));
        }

        private void ProcessValidConsoleResult(BinaryReader reader, byte[] buffer, string id)
        {
            view.consoleResult(Color.Green, id, readString(reader, buffer));
        }

        private void ProcessLogMessage(BinaryReader reader, byte[] buffer, string id)
        {
            var verbosity = reader.ReadByte();
            if (verbosity > colorTable.Length)
            {
                throw new Exception("Invalid verbosity! verb= " + verbosity);
            }

            Color color = colorTable[verbosity];
            string message = readString(reader, buffer);

            view.logMessage(color, id, "Default", message);      
        }
    }
}
